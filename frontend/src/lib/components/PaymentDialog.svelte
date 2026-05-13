<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade, fly } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';

	let {
		total,
		onConfirm,
		onCancel
	}: {
		total: number;
		onConfirm: (paidAmount: number) => void;
		onCancel: () => void;
	} = $props();

	let paidAmount = $state(0);
	let customInput = $state('');
	let changeAmount = $derived(paidAmount - total);
	let isValid = $derived(paidAmount >= total && total > 0);

	const shortcuts: { label: string; value: number | 'exact'; color: string }[] = [
		{ label: 'Uang Pas', value: 'exact' as const, color: 'bg-md-secondary-container text-md-on-secondary-container border-md-secondary/30' },
		{ label: '10rb', value: 10000, color: 'bg-md-surface-container text-md-on-surface border-md-outline-variant' },
		{ label: '20rb', value: 20000, color: 'bg-md-surface-container text-md-on-surface border-md-outline-variant' },
		{ label: '50rb', value: 50000, color: 'bg-md-surface-container text-md-on-surface border-md-outline-variant' },
		{ label: '100rb', value: 100000, color: 'bg-md-primary-container text-md-on-primary-container border-md-primary/30' },
		{ label: '200rb', value: 200000, color: 'bg-md-primary-container text-md-on-primary-container border-md-primary/30' },
		{ label: '500rb', value: 500000, color: 'bg-md-tertiary-container text-md-on-tertiary-container border-md-tertiary/30' },
		{ label: '1 Juta', value: 1000000, color: 'bg-md-tertiary-container text-md-on-tertiary-container border-md-tertiary/30' },
	];

	function selectShortcut(value: number | 'exact') {
		if (value === 'exact') {
			paidAmount = total;
			customInput = '';
		} else {
			paidAmount = value;
			customInput = '';
		}
	}

	function handleCustomInput(e: Event) {
		const val = (e.target as HTMLInputElement).value.replace(/\D/g, '');
		customInput = val;
		paidAmount = Number(val) || 0;
	}

	function formatPrice(n: number): string {
		return 'Rp ' + Math.round(n).toLocaleString('id-ID');
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="fixed inset-0 bg-black/50 z-50 flex items-end md:items-center justify-center"
	transition:fade={{ duration: 150 }}
	onkeydown={(e) => e.key === 'Escape' && onCancel()}
	onclick={(e) => { if (e.target === e.currentTarget) onCancel(); }}
>
	<div
		class="w-full max-w-lg bg-md-surface-bright rounded-t-3xl md:rounded-3xl p-6 elevation-3 max-h-[90vh] overflow-y-auto no-scrollbar"
		transition:fly={{ y: 200, duration: 280, easing: cubicOut }}
	>
		<div class="w-10 h-1 rounded-full bg-md-outline-variant mx-auto mb-4 md:hidden"></div>

		<h2 class="text-xl font-bold text-md-on-surface text-center mb-1">Pembayaran</h2>

		<!-- Total -->
		<div class="text-center mb-5 p-4 rounded-2xl bg-md-primary-container/30 border border-md-primary/20">
			<div class="text-xs text-md-on-surface-variant uppercase tracking-wider font-semibold mb-1">Total Tagihan</div>
			<div class="text-3xl font-extrabold text-md-primary tabular-nums">{formatPrice(total)}</div>
		</div>

		<!-- Shortcut Buttons -->
		<div class="grid grid-cols-4 gap-2 mb-4">
			{#each shortcuts as s}
				<button
					use:ripple
					class="py-3 rounded-xl font-semibold text-sm min-h-[48px] transition-all border active:scale-[0.96] {s.color}
					{paidAmount === (s.value === 'exact' ? total : s.value) ? 'ring-2 ring-md-primary ring-offset-1' : ''}"
					onclick={() => selectShortcut(s.value)}
				>
					{s.label}
				</button>
			{/each}
		</div>

		<!-- Custom Input -->
		<div class="mb-4">
			<label class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider mb-1.5 block">Atau masukkan nominal</label>
			<div class="relative">
				<span class="absolute left-4 top-1/2 -translate-y-1/2 text-md-on-surface-variant font-semibold">Rp</span>
				<input
					type="text"
					inputmode="numeric"
					placeholder="0"
					value={customInput}
					oninput={handleCustomInput}
					class="w-full h-14 pl-12 pr-4 rounded-xl bg-md-surface-container text-md-on-surface text-xl font-bold
						border-2 border-md-outline-variant focus:border-md-primary focus:outline-none focus:ring-2 focus:ring-md-primary/20
						transition-all tabular-nums text-right"
				/>
			</div>
		</div>

		<!-- Change Calculation -->
		{#if paidAmount > 0}
			<div class="mb-5 p-3 rounded-xl border transition-all duration-200
				{changeAmount >= 0 ? 'bg-md-secondary-container/30 border-md-secondary/20' : 'bg-md-error-container/30 border-md-error/20'}">
				<div class="flex justify-between items-center">
					<span class="text-sm font-semibold {changeAmount >= 0 ? 'text-md-on-secondary-container' : 'text-md-error'}">
						{changeAmount >= 0 ? 'Kembalian' : 'Kurang'}
					</span>
					<span class="text-xl font-extrabold tabular-nums {changeAmount >= 0 ? 'text-md-secondary' : 'text-md-error'}">
						{formatPrice(Math.abs(changeAmount))}
					</span>
				</div>
			</div>
		{/if}

		<!-- Action Buttons -->
		<div class="flex gap-3">
			<button
				use:ripple
				class="flex-1 h-14 rounded-2xl bg-md-surface-container text-md-on-surface font-semibold hover:bg-md-surface-container-high transition-colors"
				onclick={onCancel}
			>
				Batal
			</button>
			<button
				use:ripple
				disabled={!isValid}
				class="flex-[2] h-14 rounded-2xl bg-md-primary text-md-on-primary font-bold elevation-1
					disabled:opacity-30 disabled:cursor-not-allowed
					hover:opacity-95 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
				onclick={() => onConfirm(paidAmount)}
			>
				<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
				Konfirmasi & Cetak
			</button>
		</div>
	</div>
</div>
