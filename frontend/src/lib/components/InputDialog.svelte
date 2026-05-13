<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade } from 'svelte/transition';

	let {
		show = $bindable(false),
		title = 'Input',
		message = '',
		placeholder = '',
		defaultValue = '',
		type = 'input' as 'input' | 'alert' | 'confirm',
		onSubmit = (_val: string) => {},
		onCancel = () => {},
	} = $props();

	let inputValue = $state('');

	$effect(() => { if (show) inputValue = defaultValue; });

	function handleSubmit() {
		onSubmit(inputValue);
		show = false;
	}

	function handleCancel() {
		onCancel();
		show = false;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') handleSubmit();
		if (e.key === 'Escape') handleCancel();
	}
</script>

{#if show}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-[200] flex items-center justify-center p-4" transition:fade={{ duration: 150 }} onclick={(e) => { if (e.target === e.currentTarget && type !== 'alert') handleCancel(); }} onkeydown={handleKeydown}>
		<div class="w-full max-w-sm bg-md-surface-bright rounded-2xl elevation-3 overflow-hidden animate-scale-in">
			<!-- Header -->
			<div class="px-5 pt-5 pb-2">
				<h3 class="text-base font-bold text-md-on-surface">{title}</h3>
				{#if message}
					<p class="text-sm text-md-on-surface-variant mt-1">{message}</p>
				{/if}
			</div>

			<!-- Input -->
			{#if type === 'input'}
				<div class="px-5 pb-2">
					<!-- svelte-ignore a11y_autofocus -->
					<input
						type="text"
						bind:value={inputValue}
						placeholder={placeholder}
						autofocus
						class="w-full h-12 px-4 rounded-xl bg-md-surface-container border-2 border-md-outline-variant text-md-on-surface text-sm font-medium
							focus:border-md-primary focus:outline-none focus:ring-2 focus:ring-md-primary/20 transition-all"
					/>
				</div>
			{/if}

			<!-- Actions -->
			<div class="flex gap-2 p-4 pt-2 justify-end">
				{#if type !== 'alert'}
					<button use:ripple class="h-10 px-5 rounded-xl text-sm font-semibold text-md-on-surface-variant hover:bg-md-surface-container transition-colors" onclick={handleCancel}>
						Batal
					</button>
				{/if}
				<button use:ripple class="h-10 px-5 rounded-xl bg-md-primary text-md-on-primary text-sm font-bold transition-all active:scale-[0.97]" onclick={handleSubmit}>
					{type === 'alert' ? 'OK' : type === 'confirm' ? 'Ya' : 'Simpan'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	@keyframes scale-in { from { transform: scale(0.9); opacity: 0; } to { transform: scale(1); opacity: 1; } }
	.animate-scale-in { animation: scale-in 0.2s ease-out; }
</style>
