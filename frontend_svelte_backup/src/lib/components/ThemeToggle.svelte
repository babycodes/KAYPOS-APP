<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { themeStore } from '$lib/stores/theme.svelte';

	// Reactive read so Svelte tracks it
	let isDark = $derived(themeStore.isDark);
</script>

<button
	use:ripple
	class="relative flex items-center justify-center w-12 h-12 rounded-full bg-md-surface-container hover:bg-md-surface-container-high transition-colors duration-200"
	onclick={() => themeStore.toggle()}
	aria-label={isDark ? 'Aktifkan mode terang' : 'Aktifkan mode gelap'}
>
	{#if isDark}
		<!-- Sun icon -->
		<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-amber-400 transition-transform duration-300">
			<circle cx="12" cy="12" r="4"/>
			<path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>
		</svg>
	{:else}
		<!-- Moon icon -->
		<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-md-on-surface-variant transition-transform duration-300">
			<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>
		</svg>
	{/if}
</button>
