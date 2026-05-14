<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';

	let transactions = $state<any[]>([]);
	let total = $state(0);
	let now = new Date();
	let dateFilter = $state(`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`);
	let expandedId = $state<number | null>(null);
	let expandedDetails = $state<any[]>([]);
	let activeTab = $state<'day' | 'month' | 'year'>('day');
	let monthFilter = $state(`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}`);
	let yearFilter = $state(String(now.getFullYear()));
	let monthlySummary = $state<any>({ total_transactions: 0, total_sales: 0 });
	let monthlyDaily = $state<any[]>([]);

	onMount(async () => { await load(); });

	async function load() {
		if (activeTab === 'day') {
			const res = await api.get(`/transactions?date=${dateFilter}&limit=200`);
			transactions = res.data || []; total = res.total || 0;
		} else if (activeTab === 'month') {
			const [y, m] = monthFilter.split('-');
			const res = await api.get(`/reports/monthly?month=${m}&year=${y}`);
			monthlySummary = res.summary || {}; monthlyDaily = res.daily || [];
		} else {
			const res = await api.get(`/reports/monthly?month=01&year=${yearFilter}`);
			// For yearly we'll load all months
			monthlySummary = { total_transactions: 0, total_sales: 0 };
			monthlyDaily = [];
			for (let m = 1; m <= 12; m++) {
				const ms = String(m).padStart(2, '0');
				try {
					const r = await api.get(`/reports/monthly?month=${ms}&year=${yearFilter}`);
					if (r.summary?.total_transactions > 0) {
						monthlySummary.total_transactions += r.summary.total_transactions;
						monthlySummary.total_sales += r.summary.total_sales;
						monthlyDaily.push({ date: `${yearFilter}-${ms}`, count: r.summary.total_transactions, sales: r.summary.total_sales });
					}
				} catch {}
			}
		}
	}

	async function toggleExpand(id: number) {
		if (expandedId === id) { expandedId = null; return; }
		const res = await api.get(`/transactions/${id}`);
		expandedDetails = res.details;
		expandedId = id;
	}

	function switchTab(tab: 'day' | 'month' | 'year') {
		activeTab = tab; expandedId = null; load();
	}

	function fmtPrice(n: number) { return 'Rp ' + Math.round(n).toLocaleString('id-ID'); }

	let totalSales = $derived(transactions.reduce((t: number, tx: any) => t + tx.total_amount, 0));

	function getApiBase() {
		if (typeof window === 'undefined') return 'http://localhost:3000/api';
		return `http://${window.location.hostname}:3000/api`;
	}

	function exportData() {
		const token = localStorage.getItem('kaypos-token') || '';
		let url = '';
		if (activeTab === 'day') {
			url = `${getApiBase()}/reports/export?type=day&date=${dateFilter}`;
		} else if (activeTab === 'month') {
			const [y, m] = monthFilter.split('-');
			url = `${getApiBase()}/reports/export?type=month&month=${m}&year=${y}`;
		} else {
			url = `${getApiBase()}/reports/export?type=year&year=${yearFilter}`;
		}
		// Download via hidden link
		const a = document.createElement('a');
		a.href = url + `&token=${token}`;
		a.download = '';
		// Use fetch to include auth header
		fetch(url, { headers: { Authorization: `Bearer ${token}` } })
			.then(r => r.blob())
			.then(blob => {
				const bUrl = URL.createObjectURL(blob);
				a.href = bUrl;
				a.click();
				URL.revokeObjectURL(bUrl);
			});
	}
</script>

<div class="space-y-4">
	<!-- Tab Switcher -->
	<div class="flex flex-wrap gap-2 items-center justify-between">
		<div class="flex rounded-xl bg-md-surface-container p-1 border border-md-outline-variant/50">
			<button use:ripple class="px-4 py-2 rounded-lg text-sm font-semibold {activeTab === 'day' ? 'bg-md-primary text-md-on-primary shadow-sm' : 'text-md-on-surface-variant'}" onclick={() => switchTab('day')}>Harian</button>
			<button use:ripple class="px-4 py-2 rounded-lg text-sm font-semibold {activeTab === 'month' ? 'bg-md-primary text-md-on-primary shadow-sm' : 'text-md-on-surface-variant'}" onclick={() => switchTab('month')}>Bulanan</button>
			<button use:ripple class="px-4 py-2 rounded-lg text-sm font-semibold {activeTab === 'year' ? 'bg-md-primary text-md-on-primary shadow-sm' : 'text-md-on-surface-variant'}" onclick={() => switchTab('year')}>Tahunan</button>
		</div>
		<button use:ripple class="px-4 py-2 rounded-xl bg-green-600 text-white font-semibold text-sm flex items-center gap-1.5" onclick={exportData}>
			<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>
			Export Excel
		</button>
	</div>

	<!-- Filters -->
	<div class="flex flex-wrap gap-3 items-center">
		{#if activeTab === 'day'}
			<input type="date" bind:value={dateFilter} onchange={load} class="h-10 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface text-sm focus:border-md-primary focus:outline-none" />
			<span class="text-sm text-md-on-surface-variant">{total} transaksi</span>
			<div class="ml-auto px-4 py-2 rounded-xl bg-md-primary-container/30 border border-md-primary/20">
				<span class="text-xs text-md-on-surface-variant">Total:</span>
				<span class="font-bold text-md-primary ml-1">{fmtPrice(totalSales)}</span>
			</div>
		{:else if activeTab === 'month'}
			<input type="month" bind:value={monthFilter} onchange={load} class="h-10 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface text-sm focus:border-md-primary focus:outline-none" />
		{:else}
			<input type="number" bind:value={yearFilter} min="2020" max="2099" onchange={load} class="h-10 w-24 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface text-sm text-center focus:border-md-primary focus:outline-none" />
		{/if}
	</div>

	<!-- Month/Year Summary -->
	{#if activeTab !== 'day'}
		<div class="grid grid-cols-2 gap-3">
			<div class="p-4 rounded-2xl bg-md-primary-container/30 border border-md-primary/20">
				<div class="text-[10px] font-bold text-md-on-surface-variant uppercase">Total Penjualan</div>
				<div class="text-xl font-extrabold text-md-primary mt-1 tabular-nums">{fmtPrice(monthlySummary.total_sales || 0)}</div>
			</div>
			<div class="p-4 rounded-2xl bg-md-secondary-container/30 border border-md-secondary/20">
				<div class="text-[10px] font-bold text-md-on-surface-variant uppercase">Jumlah Transaksi</div>
				<div class="text-xl font-extrabold text-md-secondary mt-1">{monthlySummary.total_transactions || 0}</div>
			</div>
		</div>

		<!-- Daily/Monthly breakdown -->
		{#if monthlyDaily.length > 0}
			<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant overflow-hidden">
				<table class="w-full text-sm">
					<thead><tr class="bg-md-surface-container text-md-on-surface-variant text-left">
						<th class="px-4 py-3 font-semibold">{activeTab === 'month' ? 'Tanggal' : 'Bulan'}</th>
						<th class="px-4 py-3 font-semibold">Transaksi</th>
						<th class="px-4 py-3 font-semibold text-right">Penjualan</th>
					</tr></thead>
					<tbody>
						{#each monthlyDaily as d}
							<tr class="border-t border-md-outline-variant/50 hover:bg-md-surface-container/30">
								<td class="px-4 py-3 font-medium">{d.date}</td>
								<td class="px-4 py-3 tabular-nums">{d.count}</td>
								<td class="px-4 py-3 text-right font-bold text-md-primary tabular-nums">{fmtPrice(d.sales)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{:else}
			<div class="text-center py-8 text-sm text-md-on-surface-variant">Tidak ada data</div>
		{/if}
	{/if}

	<!-- Daily Transactions Detail -->
	{#if activeTab === 'day'}
		<!-- Mobile Cards -->
		<div class="md:hidden space-y-2">
			{#each transactions as tx (tx.id)}
				<button class="w-full p-3 rounded-xl bg-md-surface-bright border border-md-outline-variant text-left" onclick={() => toggleExpand(tx.id)}>
					<div class="flex items-center justify-between mb-1">
						<span class="text-xs text-md-on-surface-variant font-mono">#{tx.id}</span>
						<span class="text-xs text-md-on-surface-variant">{tx.created_at?.split(' ')[1] || tx.created_at}</span>
					</div>
					<div class="flex items-center justify-between">
						<span class="text-xs text-md-on-surface-variant">{tx.cashier_name || '-'}</span>
						<span class="font-bold text-sm text-md-primary tabular-nums">{fmtPrice(tx.total_amount)}</span>
					</div>
					{#if expandedId === tx.id}
						<div class="mt-2 pt-2 border-t border-md-outline-variant/30 space-y-1">
							{#each expandedDetails as d}
								<div class="flex justify-between text-[11px]">
									<span class="text-md-on-surface-variant">{d.product_name} — {d.quantity} {d.unit_used}</span>
									<span class="font-semibold">{fmtPrice(d.subtotal)}</span>
								</div>
							{/each}
							<div class="flex justify-between text-[11px] pt-1">
								<span>Bayar: {fmtPrice(tx.paid_amount)}</span>
								<span class="text-md-secondary">Kembali: {fmtPrice(tx.change_amount)}</span>
							</div>
						</div>
					{/if}
				</button>
			{/each}
			{#if transactions.length === 0}
				<div class="text-center py-8 text-sm text-md-on-surface-variant">Tidak ada transaksi</div>
			{/if}
		</div>

		<!-- Desktop Table -->
		<div class="hidden md:block rounded-2xl bg-md-surface-bright border border-md-outline-variant overflow-hidden">
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
	{/if}
</div>
