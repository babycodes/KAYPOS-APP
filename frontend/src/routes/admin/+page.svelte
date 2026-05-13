<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';

	let summary = $state<any>({ total_transactions: 0, total_sales: 0, avg_transaction: 0 });
	let lowStock = $state<any[]>([]);
	let topProducts = $state<any[]>([]);

	onMount(async () => {
		try {
			const [s, ls, tp] = await Promise.all([
				api.get('/transactions/today'),
				api.get('/inventory/low-stock'),
				api.get('/reports/products?days=7')
			]);
			summary = s;
			lowStock = ls;
			topProducts = tp.slice(0, 5);
		} catch {}
	});

	function fmtPrice(n: number) { return 'Rp ' + Math.round(n).toLocaleString('id-ID'); }
</script>

<div class="space-y-6">
	<!-- Summary Cards -->
	<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
		<div class="p-5 rounded-2xl bg-md-primary-container/30 border border-md-primary/20">
			<div class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider">Penjualan Hari Ini</div>
			<div class="text-2xl font-extrabold text-md-primary mt-1 tabular-nums">{fmtPrice(summary.total_sales)}</div>
		</div>
		<div class="p-5 rounded-2xl bg-md-secondary-container/30 border border-md-secondary/20">
			<div class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider">Jumlah Transaksi</div>
			<div class="text-2xl font-extrabold text-md-secondary mt-1">{summary.total_transactions}</div>
		</div>
		<div class="p-5 rounded-2xl bg-md-tertiary-container/30 border border-md-tertiary/20">
			<div class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider">Rata-rata / Transaksi</div>
			<div class="text-2xl font-extrabold text-md-tertiary mt-1 tabular-nums">{fmtPrice(summary.avg_transaction)}</div>
		</div>
	</div>

	<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
		<!-- Low Stock -->
		<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-5">
			<h3 class="font-bold text-md-on-surface mb-3 flex items-center gap-2">⚠️ Stok Rendah</h3>
			{#if lowStock.length === 0}
				<p class="text-sm text-md-on-surface-variant">Semua stok aman 👍</p>
			{:else}
				<div class="space-y-2">
					{#each lowStock as item}
						<div class="flex justify-between items-center p-2.5 rounded-lg bg-md-error-container/20 border border-md-error/10">
							<span class="text-sm font-medium">{item.name}</span>
							<span class="text-sm font-bold text-md-error">{Math.round(item.stock_quantity)} {item.base_unit}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Top Products -->
		<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-5">
			<h3 class="font-bold text-md-on-surface mb-3 flex items-center gap-2">🏆 Produk Terlaris (7 Hari)</h3>
			{#if topProducts.length === 0}
				<p class="text-sm text-md-on-surface-variant">Belum ada data penjualan</p>
			{:else}
				<div class="space-y-2">
					{#each topProducts as p, i}
						<div class="flex justify-between items-center p-2.5 rounded-lg bg-md-surface-container">
							<div class="flex items-center gap-2">
								<span class="w-6 h-6 rounded-full bg-md-primary-container text-md-on-primary-container text-xs font-bold flex items-center justify-center">{i + 1}</span>
								<span class="text-sm font-medium">{p.product_name}</span>
							</div>
							<span class="text-sm font-bold text-md-primary">{fmtPrice(p.total_revenue)}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
</div>
