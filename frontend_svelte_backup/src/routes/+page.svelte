<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth.svelte';

	onMount(() => {
		if (authStore.restore()) {
			goto('/kasir');
		} else {
			goto('/login');
		}
	});
</script>

<div class="min-h-screen bg-md-surface flex items-center justify-center">
	<div class="text-center">
		<div class="w-16 h-16 rounded-2xl bg-md-primary flex items-center justify-center mx-auto mb-3 animate-pulse">
			<span class="text-md-on-primary font-black text-2xl">K</span>
		</div>
		<p class="text-md-on-surface-variant text-sm">Memuat...</p>
	</div>
</div>
