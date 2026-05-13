<script lang="ts">
	import { ripple } from '$lib/actions/ripple';

	let {
		product,
		onSelect,
	}: {
		product: any;
		onSelect: (product: any) => void;
	} = $props();

	let baseUnit = $derived(product.units?.[0]);
	let pricePerOne = $derived(baseUnit ? baseUnit.price / baseUnit.qty_per_unit : 0);
	let displayUnitName = $derived(baseUnit?.unit_name || 'pcs');
	let hasMultiUnits = $derived((product.units?.length || 0) > 1);
	let categoryIcon = $derived(product.category_icon || '📦');

	function formatPrice(price: number): string {
		if (price < 1 && price > 0) return `Rp${price.toFixed(2)}`;
		return `Rp${Math.round(price).toLocaleString('id-ID')}`;
	}
</script>

<button use:ripple class="flex flex-col items-start p-2.5 md:p-4 rounded-xl md:rounded-2xl bg-md-surface-bright border border-md-outline-variant hover:border-md-primary/50 hover:bg-md-primary-container/10 transition-all duration-200 text-left active:scale-[0.97] min-h-[100px] md:min-h-[140px] elevation-1 w-full" onclick={() => onSelect(product)}>
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
</button>
