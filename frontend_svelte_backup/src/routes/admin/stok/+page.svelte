<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';

	let inventory = $state<any[]>([]);
	let filter = $state('all');
	let editId = $state<number | null>(null);
	let editStock = $state(0);
	let editMinAlert = $state(0);
	let searchQuery = $state('');

	onMount(async () => { await load(); });
	async function load() { inventory = await api.get('/inventory'); }

	let filtered = $derived(() => {
		let items = inventory;
		if (filter === 'low') items = inventory.filter((i: any) => i.min_stock_alert > 0 && i.stock_quantity <= i.min_stock_alert && i.stock_quantity > 0);
		else if (filter === 'empty') items = inventory.filter((i: any) => i.stock_quantity <= 0);
		if (searchQuery) items = items.filter((i: any) => i.name.toLowerCase().includes(searchQuery.toLowerCase()));
		return items;
	});

	let lowCount = $derived(inventory.filter((i: any) => i.min_stock_alert > 0 && i.stock_quantity <= i.min_stock_alert && i.stock_quantity > 0).length);
	let emptyCount = $derived(inventory.filter((i: any) => i.stock_quantity <= 0).length);

	function openEdit(item: any) {
		editId = item.product_id;
		editStock = Math.round(item.stock_quantity);
		editMinAlert = item.min_stock_alert || 0;
	}

	async function saveEdit(productId: number) {
		await api.put(`/inventory/${productId}`, { stock_quantity: editStock, min_stock_alert: editMinAlert });
		editId = null;
		await load();
	}
</script>

<div class="space-y-4">
	<div class="flex flex-wrap gap-2 items-center justify-between">
		<div class="flex flex-wrap gap-2">
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'all' ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'all'}>Semua ({inventory.length})</button>
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'low' ? 'bg-md-tertiary text-md-on-tertiary' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'low'}>⚠️ Stok Rendah ({lowCount})</button>
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'empty' ? 'bg-md-error text-md-on-error' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'empty'}>🚫 Stok Habis ({emptyCount})</button>
		</div>
	</div>

	<div class="relative max-w-md">
		<svg class="absolute left-3 top-1/2 -translate-y-1/2 text-md-on-surface-variant" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
		<input type="text" bind:value={searchQuery} placeholder="Cari produk..."
			class="w-full h-10 pl-10 pr-4 rounded-xl bg-md-surface-container text-sm text-md-on-surface border border-md-outline-variant/50 focus:border-md-primary focus:outline-none" />
	</div>

	<!-- Mobile Cards -->
	<div class="md:hidden space-y-2">
		{#each filtered() as item (item.product_id)}
			{@const isLow = item.min_stock_alert > 0 && item.stock_quantity <= item.min_stock_alert}
			<div class="p-3 rounded-xl bg-md-surface-bright border {isLow ? 'border-md-error/30 bg-md-error-container/5' : 'border-md-outline-variant'}">
				<div class="flex items-center justify-between mb-2">
					<div class="min-w-0 flex-1">
						<div class="font-bold text-sm truncate">{item.name}</div>
						<div class="text-[10px] text-md-on-surface-variant">{item.category_name || '-'} · {item.base_unit || '-'}</div>
					</div>
					<div class="flex items-center gap-2">
						<div class="text-right">
							<div class="text-lg font-extrabold tabular-nums {isLow ? 'text-md-error' : 'text-md-on-surface'}">{Math.round(item.stock_quantity)}</div>
							{#if item.min_stock_alert > 0}
								<div class="text-[9px] text-md-on-surface-variant">min: {item.min_stock_alert}</div>
							{/if}
						</div>
						<button use:ripple class="w-8 h-8 rounded-lg bg-md-primary-container/50 text-md-primary flex items-center justify-center shrink-0" onclick={() => openEdit(item)} title="Edit stok">
							<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>
						</button>
					</div>
				</div>
				{#if editId === item.product_id}
					<div class="flex gap-2 mt-2 pt-2 border-t border-md-outline-variant/30">
						<div class="flex-1">
							<label class="text-[9px] font-semibold text-md-on-surface-variant uppercase">Stok</label>
							<input type="number" bind:value={editStock} class="w-full h-9 px-2 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-center tabular-nums" />
						</div>
						<div class="flex-1">
							<label class="text-[9px] font-semibold text-md-on-surface-variant uppercase">Min. Alert</label>
							<input type="number" bind:value={editMinAlert} class="w-full h-9 px-2 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-center tabular-nums" />
						</div>
						<div class="flex flex-col gap-1 pt-3">
							<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-bold bg-md-primary text-md-on-primary" onclick={() => saveEdit(item.product_id)}>OK</button>
							<button use:ripple class="px-3 py-1 rounded-lg text-[10px] font-semibold bg-md-surface-container" onclick={() => editId = null}>✕</button>
						</div>
					</div>
				{/if}
			</div>
		{/each}
		{#if filtered().length === 0}
			<div class="text-center py-8 text-sm text-md-on-surface-variant">{filter === 'low' ? 'Semua stok aman 👍' : filter === 'empty' ? 'Tidak ada stok habis 👍' : 'Tidak ada data'}</div>
		{/if}
	</div>

	<!-- Desktop Table -->
	<div class="hidden md:block rounded-2xl bg-md-surface-bright border border-md-outline-variant overflow-hidden">
		<div class="overflow-x-auto">
			<table class="w-full text-sm">
				<thead><tr class="bg-md-surface-container text-md-on-surface-variant text-left">
					<th class="px-4 py-3 font-semibold">Produk</th>
					<th class="px-4 py-3 font-semibold">Kategori</th>
					<th class="px-4 py-3 font-semibold">Stok</th>
					<th class="px-4 py-3 font-semibold">Satuan</th>
					<th class="px-4 py-3 font-semibold">Min. Alert</th>
					<th class="px-4 py-3 font-semibold text-right">Aksi</th>
				</tr></thead>
				<tbody>
					{#each filtered() as item (item.product_id)}
						{@const isLow = item.min_stock_alert > 0 && item.stock_quantity <= item.min_stock_alert}
						<tr class="border-t border-md-outline-variant/50 {isLow ? 'bg-md-error-container/10' : 'hover:bg-md-surface-container/30'}">
							<td class="px-4 py-3 font-medium">{item.name}</td>
							<td class="px-4 py-3 text-md-on-surface-variant">{item.category_name || '-'}</td>
							<td class="px-4 py-3">
								{#if editId === item.product_id}
									<input type="number" bind:value={editStock} class="w-20 h-8 px-2 rounded-lg bg-md-surface-container border border-md-primary text-sm text-center tabular-nums font-bold" />
								{:else}
									<span class="font-bold tabular-nums {isLow ? 'text-md-error' : 'text-md-on-surface'}">{Math.round(item.stock_quantity)}</span>
								{/if}
							</td>
							<td class="px-4 py-3">{item.base_unit || '-'}</td>
							<td class="px-4 py-3">
								{#if editId === item.product_id}
									<input type="number" bind:value={editMinAlert} class="w-20 h-8 px-2 rounded-lg bg-md-surface-container border border-md-primary text-sm text-center tabular-nums" />
								{:else}
									<span class="text-md-on-surface-variant tabular-nums">{item.min_stock_alert || '-'}</span>
								{/if}
							</td>
							<td class="px-4 py-3 text-right">
								{#if editId === item.product_id}
									<div class="flex justify-end gap-1">
										<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-bold bg-md-primary text-md-on-primary" onclick={() => saveEdit(item.product_id)}>Simpan</button>
										<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-md-surface-container" onclick={() => editId = null}>Batal</button>
									</div>
								{:else}
									<button use:ripple class="w-8 h-8 rounded-lg bg-md-primary-container/50 text-md-primary flex items-center justify-center" onclick={() => openEdit(item)} title="Edit stok">
										<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>
									</button>
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</div>
</div>
