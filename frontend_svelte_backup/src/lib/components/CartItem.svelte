<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade } from 'svelte/transition';

	let {
		item,
		onIncrement,
		onDecrement,
		onRemove,
		onSetQuantity
	}: {
		item: any;
		onIncrement: () => void;
		onDecrement: () => void;
		onRemove: () => void;
		onSetQuantity?: (qty: number) => void;
	} = $props();

	let subtotal = $derived(item.unit_price * item.quantity);
	let editing = $state(false);
	let editVal = $state('');

	function formatPrice(price: number): string {
		if (price < 1) return `Rp ${price.toFixed(2)}`;
		return `Rp ${price.toLocaleString('id-ID')}`;
	}

	function startEdit() {
		editVal = String(item.quantity);
		editing = true;
		// Focus on next tick
		setTimeout(() => {
			const el = document.getElementById(`qty-edit-${item.product.id}-${item.selected_unit}`);
			if (el) { (el as HTMLInputElement).select(); el.focus(); }
		}, 50);
	}

	function commitEdit() {
		const val = parseFloat(editVal);
		if (!isNaN(val) && val > 0 && onSetQuantity) {
			onSetQuantity(val);
		}
		editing = false;
	}
</script>

<div
	class="flex items-center gap-3 p-3 rounded-xl bg-md-surface-container-low border border-md-outline-variant/60 transition-all duration-200 hover:border-md-outline"
	in:fade={{ duration: 200 }}
>
	<!-- Product Info -->
	<div class="flex-1 min-w-0">
		<div class="font-bold text-sm text-md-on-surface truncate">{item.product.name}</div>
		<div class="flex items-center gap-1.5 mt-0.5">
			<span class="text-xs text-md-on-surface-variant">
				{formatPrice(item.unit_price)}
			</span>
			<span class="text-xs text-md-on-surface-variant">×</span>
			<span class="text-xs font-medium text-md-primary">
				{item.quantity} {item.selected_unit}
			</span>
		</div>
	</div>

	<!-- Subtotal -->
	<div class="shrink-0 text-right mr-2">
		<div class="font-bold text-sm text-md-primary tabular-nums">
			{formatPrice(subtotal)}
		</div>
	</div>

	<!-- Quantity Controls -->
	<div class="shrink-0 flex items-center gap-1 bg-md-surface-bright rounded-lg p-0.5 border border-md-outline-variant">
		<button
			use:ripple
			class="w-8 h-8 rounded-md flex items-center justify-center transition-colors
			{item.quantity <= 1
				? 'bg-md-error-container/50 text-md-error hover:bg-md-error-container'
				: 'bg-md-surface-container hover:bg-md-surface-container-high text-md-on-surface'}"
			onclick={() => {
				if (item.quantity <= 1) onRemove();
				else onDecrement();
			}}
			aria-label={item.quantity <= 1 ? 'Hapus item' : 'Kurangi'}
		>
			{#if item.quantity <= 1}
				<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
			{:else}
				<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14"/></svg>
			{/if}
		</button>
		{#if editing}
			<input
				id="qty-edit-{item.product.id}-{item.selected_unit}"
				type="number"
				bind:value={editVal}
				class="w-10 h-7 text-xs font-bold text-center bg-md-surface-container rounded border border-md-primary tabular-nums text-md-on-surface [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
				min="0.1"
				step="any"
				onblur={commitEdit}
				onkeydown={(e) => { if (e.key === 'Enter') commitEdit(); }}
			/>
		{:else}
			<button class="font-bold text-xs text-md-on-surface w-8 text-center tabular-nums hover:bg-md-surface-container rounded h-7 flex items-center justify-center" onclick={startEdit} title="Klik untuk edit qty">{item.quantity}</button>
		{/if}
		<button
			use:ripple
			class="w-8 h-8 rounded-md flex items-center justify-center bg-md-primary text-md-on-primary hover:opacity-90 transition-colors"
			onclick={onIncrement}
			aria-label="Tambah"
		>
			<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M5 12h14"/><path d="M12 5v14"/></svg>
		</button>
	</div>
</div>
