<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';

	let summary = $state<any>({ total_transactions: 0, total_sales: 0, avg_transaction: 0 });
	let lowStock = $state<any[]>([]);
	let topProducts = $state<any[]>([]);
	let chartData = $state<any[]>([]);
	let chartMax = $derived(Math.max(...chartData.map(d => d.sales), 1));

	onMount(async () => {
		try {
			const [s, ls, tp, cd] = await Promise.all([
				api.get('/transactions/today'),
				api.get('/inventory/low-stock'),
				api.get('/reports/products?days=7'),
				api.get('/reports/chart28')
			]);
			summary = s;
			lowStock = ls;
			topProducts = tp.slice(0, 5);
			chartData = cd;
		} catch {}
	});

	function fmtPrice(n: number) { return 'Rp ' + Math.round(n).toLocaleString('id-ID'); }
	function fmtK(n: number) { return n >= 1000000 ? (n/1000000).toFixed(1) + 'jt' : n >= 1000 ? (n/1000).toFixed(0) + 'rb' : String(n); }
	function shortDate(d: string) { const p = d.split('-'); return `${p[2]}/${p[1]}`; }
</script>

<div class="space-y-6">
	<!-- Summary Cards -->
	<div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
		<div class="p-4 rounded-2xl bg-md-primary-container/30 border border-md-primary/20">
			<div class="text-[10px] font-bold text-md-on-surface-variant uppercase tracking-wider">Penjualan Hari Ini</div>
			<div class="text-xl font-extrabold text-md-primary mt-1 tabular-nums">{fmtPrice(summary.total_sales)}</div>
		</div>
		<div class="p-4 rounded-2xl bg-md-secondary-container/30 border border-md-secondary/20">
			<div class="text-[10px] font-bold text-md-on-surface-variant uppercase tracking-wider">Jumlah Transaksi</div>
			<div class="text-xl font-extrabold text-md-secondary mt-1">{summary.total_transactions}</div>
		</div>
		<div class="p-4 rounded-2xl bg-md-tertiary-container/30 border border-md-tertiary/20">
			<div class="text-[10px] font-bold text-md-on-surface-variant uppercase tracking-wider">Rata-rata / Transaksi</div>
			<div class="text-xl font-extrabold text-md-tertiary mt-1 tabular-nums">{fmtPrice(summary.avg_transaction)}</div>
		</div>
	</div>

	<!-- 28-Day Sales Chart -->
	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-4">
		<h3 class="font-bold text-sm text-md-on-surface mb-3 flex items-center gap-2">
			<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>
			Penjualan 28 Hari Terakhir
		</h3>
		{#if chartData.length > 0}
			<div class="flex items-end gap-[2px] h-36 w-full">
				{#each chartData as d, i}
					{@const pct = chartMax > 0 ? (d.sales / chartMax) * 100 : 0}
					{@const isToday = i === chartData.length - 1}
					<div class="flex-1 flex flex-col items-center justify-end h-full group relative">
						<div class="absolute -top-6 left-1/2 -translate-x-1/2 hidden group-hover:block z-10 px-2 py-1 rounded-lg bg-md-inverse-surface text-md-inverse-on-surface text-[9px] font-bold whitespace-nowrap">
							{shortDate(d.date)}: {fmtK(d.sales)} ({d.count}x)
						</div>
						<div class="w-full rounded-t transition-all duration-300 min-h-[2px]
							{isToday ? 'bg-md-primary' : 'bg-md-primary/40 hover:bg-md-primary/70'}"
							style="height: {Math.max(pct, 1.5)}%">
						</div>
					</div>
				{/each}
			</div>
			<div class="flex justify-between mt-1">
				<span class="text-[9px] text-md-on-surface-variant">{shortDate(chartData[0]?.date)}</span>
				<span class="text-[9px] text-md-on-surface-variant font-bold">Hari ini</span>
			</div>
		{:else}
			<p class="text-sm text-md-on-surface-variant text-center py-8">Belum ada data</p>
		{/if}
	</div>

	<div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
		<!-- Low Stock -->
		<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-4">
			<h3 class="font-bold text-sm text-md-on-surface mb-3 flex items-center gap-2">
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="text-md-error"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
				Stok Rendah
			</h3>
			{#if lowStock.length === 0}
				<p class="text-sm text-md-on-surface-variant">Semua stok aman 👍</p>
			{:else}
				<div class="space-y-2 max-h-48 overflow-y-auto no-scrollbar">
					{#each lowStock as item}
						<div class="flex justify-between items-center p-2.5 rounded-lg bg-md-error-container/20 border border-md-error/10">
							<span class="text-xs font-medium">{item.name}</span>
							<span class="text-xs font-bold text-md-error tabular-nums">{Math.round(item.stock_quantity)} {item.base_unit}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Top Products -->
		<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-4">
			<h3 class="font-bold text-sm text-md-on-surface mb-3 flex items-center gap-2">
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="text-md-primary"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5C7 4 9 7 12 7s5-3 7.5-3a2.5 2.5 0 0 1 0 5H18"/><path d="M18 9v10a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V9"/><path d="M12 7v14"/></svg>
				Produk Terlaris (7 Hari)
			</h3>
			{#if topProducts.length === 0}
				<p class="text-sm text-md-on-surface-variant">Belum ada data penjualan</p>
			{:else}
				<div class="space-y-2">
					{#each topProducts as p, i}
						<div class="flex justify-between items-center p-2.5 rounded-lg bg-md-surface-container">
							<div class="flex items-center gap-2 min-w-0">
								<span class="w-6 h-6 rounded-full bg-md-primary-container text-md-on-primary-container text-xs font-bold flex items-center justify-center shrink-0">{i + 1}</span>
								<span class="text-xs font-medium truncate">{p.product_name}</span>
							</div>
							<span class="text-xs font-bold text-md-primary tabular-nums shrink-0 ml-2">{fmtPrice(p.total_revenue)}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
</div>
