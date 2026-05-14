<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';

	let inventory = $state<any[]>([]);
	let filter = $state('all');
	let adjustId = $state<number | null>(null);
	let adjustVal = $state(0);
	let searchQuery = $state('');

	onMount(async () => { await load(); });
	async function load() { inventory = await api.get('/inventory'); }

	let filtered = $derived(() => {
		let items = filter === 'low' ? inventory.filter((i: any) => i.min_stock_alert > 0 && i.stock_quantity <= i.min_stock_alert) : inventory;
		if (searchQuery) items = items.filter((i: any) => i.name.toLowerCase().includes(searchQuery.toLowerCase()));
		return items;
	});

	let lowCount = $derived(inventory.filter((i: any) => i.min_stock_alert > 0 && i.stock_quantity <= i.min_stock_alert).length);

	async function doAdjust(productId: number) {
		if (adjustVal === 0) return;
		await api.put(`/inventory/${productId}`, { adjustment: adjustVal });
		adjustId = null; adjustVal = 0;
		await load();
	}
</script>

<div class="space-y-4">
	<div class="flex flex-wrap gap-2 items-center justify-between">
		<div class="flex gap-2">
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'all' ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'all'}>Semua ({inventory.length})</button>
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'low' ? 'bg-md-error text-md-on-error' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'low'}>⚠️ Stok Rendah ({lowCount})</button>
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
						<div class="text-[10px] text-md-on-surface-variant">{item.category_name || '-'} · {item.base_unit}</div>
					</div>
					<div class="text-right ml-2">
						<div class="text-lg font-extrabold tabular-nums {isLow ? 'text-md-error' : 'text-md-on-surface'}">{Math.round(item.stock_quantity)}</div>
						{#if item.min_stock_alert > 0}
							<div class="text-[9px] text-md-on-surface-variant">min: {item.min_stock_alert}</div>
						{/if}
					</div>
				</div>
				{#if adjustId === item.product_id}
					<div class="flex items-center gap-2">
						<input type="number" bind:value={adjustVal} placeholder="+100 / -50" class="flex-1 h-9 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-center" />
						<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-bold bg-md-primary text-md-on-primary" onclick={() => doAdjust(item.product_id)}>OK</button>
						<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-md-surface-container" onclick={() => adjustId = null}>✕</button>
					</div>
				{:else}
					<button use:ripple class="w-full py-1.5 rounded-lg text-[11px] font-semibold bg-md-primary-container/50 text-md-primary" onclick={() => { adjustId = item.product_id; adjustVal = 0; }}>± Adjustment</button>
				{/if}
			</div>
		{/each}
		{#if filtered().length === 0}
			<div class="text-center py-8 text-sm text-md-on-surface-variant">{filter === 'low' ? 'Semua stok aman 👍' : 'Tidak ada data'}</div>
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
							<td class="px-4 py-3 font-bold tabular-nums {isLow ? 'text-md-error' : 'text-md-on-surface'}">{Math.round(item.stock_quantity)}</td>
							<td class="px-4 py-3">{item.base_unit}</td>
							<td class="px-4 py-3 text-md-on-surface-variant tabular-nums">{item.min_stock_alert || '-'}</td>
							<td class="px-4 py-3 text-right">
								{#if adjustId === item.product_id}
									<div class="flex items-center gap-2 justify-end">
										<input type="number" bind:value={adjustVal} placeholder="+100 / -50" class="w-24 h-9 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-center" />
										<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-bold bg-md-primary text-md-on-primary" onclick={() => doAdjust(item.product_id)}>OK</button>
										<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-md-surface-container text-md-on-surface" onclick={() => adjustId = null}>✕</button>
									</div>
								{:else}
									<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-md-primary-container/50 text-md-primary" onclick={() => { adjustId = item.product_id; adjustVal = 0; }}>Adjustment</button>
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</div>
</div>
