<script lang="ts">
	import './layout.css';
	import { onMount } from 'svelte';
	import { themeStore } from '$lib/stores/theme.svelte';
	import { authStore } from '$lib/stores/auth.svelte';

	let { children } = $props();

	onMount(() => {
		themeStore.init();
		authStore.restore();
	});
</script>

{@render children()}
