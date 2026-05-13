<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';

	let transactions = $state<any[]>([]);
	let total = $state(0);
	let dateFilter = $state(new Date().toISOString().split('T')[0]);
	let expandedId = $state<number | null>(null);
	let expandedDetails = $state<any[]>([]);

	onMount(async () => { await load(); });

	async function load() {
		const res = await api.get(`/transactions?date=${dateFilter}&limit=100`);
		transactions = res.data; total = res.total;
	}

	async function toggleExpand(id: number) {
		if (expandedId === id) { expandedId = null; return; }
		const res = await api.get(`/transactions/${id}`);
		expandedDetails = res.details;
		expandedId = id;
	}

	function fmtPrice(n: number) { return 'Rp ' + Math.round(n).toLocaleString('id-ID'); }

	let totalSales = $derived(transactions.reduce((t: number, tx: any) => t + tx.total_amount, 0));
</script>

<div class="space-y-4">
	<div class="flex flex-wrap gap-3 items-center justify-between">
		<div class="flex items-center gap-3">
			<input type="date" bind:value={dateFilter} onchange={load} class="h-10 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface text-sm focus:border-md-primary focus:outline-none" />
			<span class="text-sm text-md-on-surface-variant">{total} transaksi</span>
		</div>
		<div class="px-4 py-2 rounded-xl bg-md-primary-container/30 border border-md-primary/20">
			<span class="text-xs text-md-on-surface-variant">Total:</span>
			<span class="font-bold text-md-primary ml-1">{fmtPrice(totalSales)}</span>
		</div>
	</div>

	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant overflow-hidden">
		<div class="overflow-x-auto">
			<table class="w-full text-sm">
				<thead><tr class="bg-md-surface-container text-md-on-surface-variant text-left">
					<th class="px-4 py-3 font-semibold">#</th>
					<th class="px-4 py-3 font-semibold">Waktu</th>
					<th class="px-4 py-3 font-semibold">Kasir</th>
					<th class="px-4 py-3 font-semibold">Total</th>
					<th class="px-4 py-3 font-semibold">Bayar</th>
					<th class="px-4 py-3 font-semibold">Kembali</th>
				</tr></thead>
				<tbody>
					{#each transactions as tx (tx.id)}
						<tr class="border-t border-md-outline-variant/50 hover:bg-md-surface-container/30 cursor-pointer" onclick={() => toggleExpand(tx.id)}>
							<td class="px-4 py-3 font-mono text-md-on-surface-variant">#{tx.id}</td>
							<td class="px-4 py-3">{tx.created_at?.split(' ')[1] || tx.created_at}</td>
							<td class="px-4 py-3">{tx.cashier_name || '-'}</td>
							<td class="px-4 py-3 font-bold text-md-primary tabular-nums">{fmtPrice(tx.total_amount)}</td>
							<td class="px-4 py-3 tabular-nums">{fmtPrice(tx.paid_amount)}</td>
							<td class="px-4 py-3 tabular-nums text-md-secondary">{fmtPrice(tx.change_amount)}</td>
						</tr>
						{#if expandedId === tx.id}
							<tr><td colspan="6" class="px-4 py-3 bg-md-surface-container/20">
								<div class="space-y-1">
									{#each expandedDetails as d}
										<div class="flex justify-between text-xs">
											<span>{d.product_name} — {d.quantity} {d.unit_used}</span>
											<span class="font-semibold">{fmtPrice(d.subtotal)}</span>
										</div>
									{/each}
								</div>
							</td></tr>
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	</div>
</div>
