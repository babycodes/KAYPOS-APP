<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade, fly } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';

	let {
		title = 'Konfirmasi',
		message,
		confirmText = 'Hapus',
		cancelText = 'Batal',
		danger = true,
		onConfirm,
		onCancel
	}: {
		title?: string;
		message: string;
		confirmText?: string;
		cancelText?: string;
		danger?: boolean;
		onConfirm: () => void;
		onCancel: () => void;
	} = $props();
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="fixed inset-0 bg-black/50 z-[60] flex items-center justify-center p-4" transition:fade={{ duration: 150 }}
	onkeydown={(e) => e.key === 'Escape' && onCancel()}
	onclick={(e) => { if (e.target === e.currentTarget) onCancel(); }}>
	<div class="w-full max-w-sm bg-md-surface-bright rounded-2xl p-6 elevation-3" transition:fly={{ y: 50, duration: 200, easing: cubicOut }}>
		<div class="flex items-center gap-3 mb-3">
			{#if danger}
				<div class="w-10 h-10 rounded-full bg-md-error-container flex items-center justify-center shrink-0">
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-md-error"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" x2="12" y1="9" y2="13"/><line x1="12" x2="12.01" y1="17" y2="17"/></svg>
				</div>
			{/if}
			<h3 class="text-lg font-bold text-md-on-surface">{title}</h3>
		</div>
		<p class="text-sm text-md-on-surface-variant mb-5 leading-relaxed">{message}</p>
		<div class="flex gap-3">
			<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold hover:bg-md-surface-container-high transition-colors" onclick={onCancel}>{cancelText}</button>
			<button use:ripple class="flex-[2] h-12 rounded-xl font-bold transition-all active:scale-[0.98]
				{danger ? 'bg-md-error text-md-on-error' : 'bg-md-primary text-md-on-primary'}" onclick={onConfirm}>{confirmText}</button>
		</div>
	</div>
</div>
