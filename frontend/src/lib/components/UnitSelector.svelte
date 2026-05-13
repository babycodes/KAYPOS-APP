<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade, fly } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';

	let {
		product,
		onConfirm,
		onCancel
	}: {
		product: any;
		onConfirm: (product: any, unitName: string, quantity: number) => void;
		onCancel: () => void;
	} = $props();

	let selectedUnit = $state(product.units?.[0]?.unit_name || '');
	let quantity = $state(1);

	let selectedUnitData = $derived(product.units?.find((u: any) => u.unit_name === selectedUnit));
	// Price per 1 unit = price / qty_per_unit
	let pricePerOne = $derived(selectedUnitData ? selectedUnitData.price / selectedUnitData.qty_per_unit : 0);
	let totalPrice = $derived(pricePerOne * quantity);

	function formatPrice(n: number): string {
		if (n < 1 && n > 0) return `Rp ${n.toFixed(2)}`;
		return `Rp ${Math.round(n).toLocaleString('id-ID')}`;
	}

	function formatUnitLabel(u: any): string {
		if (u.qty_per_unit > 1) return `${u.qty_per_unit} ${u.unit_name} = ${formatPrice(u.price)}`;
		return `${u.unit_name} = ${formatPrice(u.price)}`;
	}

	function handleConfirm() {
		if (quantity > 0) onConfirm(product, selectedUnit, quantity);
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="fixed inset-0 bg-black/50 z-50 flex items-end md:items-center justify-center" transition:fade={{ duration: 150 }}
	onkeydown={(e) => e.key === 'Escape' && onCancel()}
	onclick={(e) => { if (e.target === e.currentTarget) onCancel(); }}>
	<div class="w-full max-w-md bg-md-surface-bright rounded-t-3xl md:rounded-3xl elevation-3 overflow-hidden"
		transition:fly={{ y: 300, duration: 280, easing: cubicOut }}>

		<!-- Product Header -->
		<div class="p-5 pb-3 border-b border-md-outline-variant/30">
			<div class="flex items-center gap-3 mb-1">
				<span class="text-2xl">{product.category_icon || '📦'}</span>
				<div class="flex-1 min-w-0">
					<h3 class="font-bold text-md-on-surface truncate">{product.name}</h3>
					<p class="text-xs text-md-on-surface-variant">{product.category_name || ''}</p>
				</div>
			</div>
		</div>

		<div class="p-5 space-y-4">
			<!-- Unit Selection -->
			<div>
				<span class="text-sm font-semibold text-md-on-surface mb-2 block">Pilih Satuan</span>
				<div class="grid grid-cols-2 gap-2">
					{#each product.units as u (u.unit_name)}
						<button use:ripple class="p-3 rounded-xl text-left transition-all border-2
							{selectedUnit === u.unit_name ? 'border-md-primary bg-md-primary-container/30' : 'border-md-outline-variant/50 bg-md-surface-container hover:border-md-primary/30'}"
							onclick={() => selectedUnit = u.unit_name}>
							<div class="font-bold text-sm text-md-on-surface">{u.unit_name}</div>
							<div class="text-xs text-md-on-surface-variant mt-0.5">
								{u.qty_per_unit > 1 ? `${u.qty_per_unit} ${u.unit_name} = ` : ''}{formatPrice(u.price)}
							</div>
						</button>
					{/each}
				</div>
			</div>

			<!-- Quantity (editable, supports decimals) -->
			<div class="flex items-center justify-between">
				<span class="text-sm font-semibold text-md-on-surface">Jumlah</span>
				<div class="flex items-center gap-3 bg-md-surface-container rounded-xl p-1 border border-md-outline-variant">
					<button use:ripple class="w-11 h-11 rounded-lg flex items-center justify-center bg-md-surface-bright hover:bg-md-surface-dim transition-colors text-md-on-surface" onclick={() => { if (quantity > 0.25) quantity = Math.round((quantity - (quantity >= 1 ? 1 : 0.25)) * 100) / 100; }} disabled={quantity <= 0.25}>
						<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14"/></svg>
					</button>
					<input type="number" bind:value={quantity} min="0.01" step="any"
						class="w-20 h-10 text-center font-bold text-xl text-md-on-surface bg-transparent border-none outline-none tabular-nums [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none" />
					<button use:ripple class="w-11 h-11 rounded-lg flex items-center justify-center bg-md-primary text-md-on-primary hover:opacity-90 transition-colors" onclick={() => quantity = Math.round((quantity + 1) * 100) / 100}>
						<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14"/><path d="M12 5v14"/></svg>
					</button>
				</div>
			</div>

			<!-- Info -->
			{#if selectedUnitData && selectedUnitData.qty_per_unit > 1}
				<div class="text-xs text-md-on-surface-variant bg-md-surface-container/50 p-2 rounded-lg">
					💡 Harga: {selectedUnitData.qty_per_unit} {selectedUnit} = {formatPrice(selectedUnitData.price)} → per 1 {selectedUnit} = {formatPrice(pricePerOne)}
				</div>
			{/if}

			<!-- Total -->
			<div class="flex items-center justify-between p-3 rounded-xl bg-md-secondary-container/30 border border-md-secondary/20">
				<span class="text-sm font-semibold text-md-on-surface">Total</span>
				<span class="text-xl font-bold text-md-secondary tabular-nums">{formatPrice(totalPrice)}</span>
			</div>

			<!-- Buttons -->
			<div class="flex gap-3">
				<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold hover:bg-md-surface-container-high transition-colors" onclick={onCancel}>Batal</button>
				<button use:ripple class="flex-[2] h-12 rounded-xl bg-md-primary text-md-on-primary font-bold elevation-1 hover:opacity-95 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
					onclick={handleConfirm} disabled={quantity <= 0}>
					<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/></svg>
					Tambah ke Keranjang
				</button>
			</div>
		</div>
	</div>
</div>
