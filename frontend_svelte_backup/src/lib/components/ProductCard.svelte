<script lang="ts">
	import { ripple } from '$lib/actions/ripple';

	let {
		product,
		onSelect,
		heldQty = 0,
	}: {
		product: any;
		onSelect: (product: any) => void;
		heldQty?: number;
	} = $props();

	let baseUnit = $derived(product.units?.[0]);
	let pricePerOne = $derived(baseUnit ? baseUnit.price / baseUnit.qty_per_unit : 0);
	let displayUnitName = $derived(baseUnit?.unit_name || 'pcs');
	let hasMultiUnits = $derived((product.units?.length || 0) > 1);
	let categoryIcon = $derived(product.category_icon || '📦');

	let realStock = $derived(product.stock_quantity ?? Infinity);
	let availableStock = $derived(realStock === Infinity ? Infinity : Math.max(0, realStock - heldQty));
	let isReallyEmpty = $derived(realStock <= 0);
	let isBookedOut = $derived(!isReallyEmpty && availableStock <= 0 && heldQty > 0);
	let blocked = $derived(isReallyEmpty || isBookedOut);

	function formatPrice(price: number): string {
		if (price < 1 && price > 0) return `Rp${price.toFixed(2)}`;
		return `Rp${Math.round(price).toLocaleString('id-ID')}`;
	}
</script>

<button use:ripple
	class="relative flex flex-col items-start p-2.5 md:p-4 rounded-xl md:rounded-2xl bg-md-surface-bright border border-md-outline-variant hover:border-md-primary/50 hover:bg-md-primary-container/10 transition-all duration-200 text-left active:scale-[0.97] min-h-[100px] md:min-h-[140px] elevation-1 w-full {blocked ? 'opacity-60 pointer-events-none grayscale-[30%]' : ''}"
	disabled={blocked}
	onclick={() => onSelect(product)}>
	<div class="w-full">
		<div class="flex items-start justify-between w-full">
			<span class="text-base md:text-lg">{categoryIcon}</span>
			{#if hasMultiUnits}
				<span class="text-[9px] md:text-[10px] px-1.5 py-0.5 rounded-full bg-md-tertiary-container text-md-on-tertiary-container font-semibold">{product.units.length}</span>
			{/if}
		</div>
		<div class="font-semibold text-[11px] md:text-sm text-md-on-surface line-clamp-2 leading-tight mt-1">{product.name}</div>
	</div>
	<div class="w-full mt-auto pt-1.5 md:pt-2 border-t border-md-outline-variant/30">
		<span class="text-[9px] md:text-[11px] text-md-on-surface-variant font-medium">/{displayUnitName}</span>
		<div class="font-bold text-md-primary text-xs md:text-sm">{formatPrice(pricePerOne)}</div>
	</div>

	{#if isReallyEmpty}
		<div class="absolute inset-0 rounded-xl md:rounded-2xl bg-md-error/15 flex flex-col items-center justify-center gap-1 pointer-events-none">
			<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-md-error drop-shadow-sm">
				<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>
			</svg>
			<span class="text-[9px] md:text-[10px] font-extrabold text-md-error tracking-wider uppercase">Stok Habis</span>
		</div>
	{:else if isBookedOut}
		<div class="absolute inset-0 rounded-xl md:rounded-2xl bg-amber-500/15 flex flex-col items-center justify-center gap-1 pointer-events-none">
			<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-amber-600 drop-shadow-sm">
				<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
			</svg>
			<span class="text-[8px] md:text-[9px] font-extrabold text-amber-700 tracking-wider uppercase text-center leading-tight px-1">Terbooking</span>
		</div>
	{/if}
</button>
