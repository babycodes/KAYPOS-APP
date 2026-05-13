<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';

	let inventory = $state<any[]>([]);
	let filter = $state('all');
	let adjustId = $state<number | null>(null);
	let adjustVal = $state(0);

	onMount(async () => { await load(); });
	async function load() { inventory = await api.get('/inventory'); }

	let filtered = $derived(filter === 'low' ? inventory.filter((i: any) => i.min_stock_alert > 0 && i.stock_quantity <= i.min_stock_alert) : inventory);

	async function doAdjust(productId: number) {
		if (adjustVal === 0) return;
		await api.put(`/inventory/${productId}`, { adjustment: adjustVal });
		adjustId = null; adjustVal = 0;
		await load();
	}
</script>

<div class="space-y-4">
	<div class="flex justify-between items-center">
		<div class="flex gap-2">
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'all' ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'all'}>Semua ({inventory.length})</button>
			<button use:ripple class="px-4 py-2 rounded-full text-sm font-medium {filter === 'low' ? 'bg-md-error text-md-on-error' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => filter = 'low'}>⚠️ Stok Rendah</button>
		</div>
	</div>

	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant overflow-hidden">
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
					{#each filtered as item (item.product_id)}
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
										<input type="number" bind:value={adjustVal} placeholder="+100 / -50" class="w-24 h-9 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface text-center" />
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
