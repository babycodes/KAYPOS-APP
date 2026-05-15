<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade, fly } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';
	import { api } from '$lib/api';

	let {
		transaction,
		details,
		onClose
	}: {
		transaction: any;
		details: any[];
		onClose: () => void;
	} = $props();

	let printing = $state(false);

	function fmtPrice(n: number) {
		if (n < 1 && n > 0) return `Rp ${n.toFixed(2)}`;
		return `Rp ${Math.round(n).toLocaleString('id-ID')}`;
	}

	function fmtDate(d: string) {
		return new Date(d).toLocaleString('id-ID', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
	}

	async function handlePrint() {
		printing = true;
		try {
			await api.post('/print/receipt', { transaction_id: transaction.id });
		} catch (e: any) {
			// Fallback: browser print
			window.print();
		}
		printing = false;
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" transition:fade={{ duration: 150 }}
	onkeydown={(e) => e.key === 'Escape' && onClose()}>
	<div class="w-full max-w-sm bg-md-surface-bright rounded-3xl elevation-3 overflow-hidden" transition:fly={{ y: 200, duration: 280, easing: cubicOut }}>

		<!-- Success Header -->
		<div class="bg-gradient-to-br from-green-500 to-emerald-600 p-6 text-center">
			<div class="w-16 h-16 bg-white/20 rounded-full flex items-center justify-center mx-auto mb-3">
				<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
			</div>
			<h2 class="text-white text-xl font-bold">Transaksi Berhasil!</h2>
			<p class="text-white/80 text-sm mt-1">#{transaction.id} — {fmtDate(transaction.created_at)}</p>
		</div>

		<!-- Receipt Body -->
		<div class="p-5 max-h-[50vh] overflow-y-auto no-scrollbar">
			<!-- Items -->
			<div class="space-y-2 mb-4">
				{#each details as d}
					<div class="flex justify-between items-start text-sm">
						<div class="flex-1 min-w-0">
							<div class="font-medium text-md-on-surface truncate">{d.product_name}</div>
							<div class="text-xs text-md-on-surface-variant">{d.quantity} {d.unit_used} × {fmtPrice(d.sold_price)}</div>
						</div>
						<span class="font-semibold text-md-on-surface tabular-nums ml-2">{fmtPrice(d.subtotal)}</span>
					</div>
				{/each}
			</div>

			<div class="border-t border-dashed border-md-outline-variant pt-3 space-y-2">
				<div class="flex justify-between text-sm">
					<span class="text-md-on-surface-variant">Total</span>
					<span class="font-bold text-md-on-surface tabular-nums">{fmtPrice(transaction.total_amount)}</span>
				</div>
				<div class="flex justify-between text-sm">
					<span class="text-md-on-surface-variant">Bayar</span>
					<span class="font-semibold text-md-on-surface tabular-nums">{fmtPrice(transaction.paid_amount)}</span>
				</div>
				<div class="flex justify-between items-center p-2 -mx-1 rounded-lg bg-md-secondary-container/30">
					<span class="font-semibold text-md-secondary text-sm">Kembali</span>
					<span class="font-extrabold text-lg text-md-secondary tabular-nums">{fmtPrice(transaction.change_amount)}</span>
				</div>
			</div>

			{#if transaction.cashier_name}
				<div class="mt-3 text-xs text-center text-md-on-surface-variant">Kasir: {transaction.cashier_name}</div>
			{/if}
		</div>

		<!-- Actions -->
		<div class="p-4 pt-0 flex gap-3">
			<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold text-sm hover:bg-md-surface-container-high transition-colors" onclick={onClose}>
				Tutup
			</button>
			<button use:ripple disabled={printing}
				class="flex-[2] h-12 rounded-xl bg-md-primary text-md-on-primary font-bold text-sm elevation-1 hover:opacity-95 transition-all active:scale-[0.98] flex items-center justify-center gap-2 disabled:opacity-50"
				onclick={handlePrint}>
				<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/><rect x="6" y="14" width="12" height="8" rx="1"/></svg>
				{printing ? 'Mencetak...' : 'Cetak Nota'}
			</button>
		</div>
	</div>
</div>
