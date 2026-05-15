<script lang="ts">
	import { ripple } from '$lib/actions/ripple';
	import { fade } from 'svelte/transition';
	import { authStore } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';

	let pin = $state('');
	let error = $state('');
	let loading = $state(false);
	let attempts = $state(0);
	const MAX_ATTEMPTS = 3;

	async function handleUnlock() {
		if (pin.length !== 6) return;
		loading = true;
		error = '';
		const ok = await authStore.unlock(pin);
		if (!ok) {
			attempts++;
			if (attempts >= MAX_ATTEMPTS) {
				alert('PIN salah 3x. Silahkan login kembali.');
				authStore.logout();
				goto('/login');
				return;
			}
			error = `PIN salah (${attempts}/${MAX_ATTEMPTS})`;
			pin = '';
		}
		loading = false;
	}

	function handleLogout() {
		authStore.logout();
		goto('/login');
	}

	function handleInput(e: Event) {
		const input = e.target as HTMLInputElement;
		// Only allow digits
		pin = input.value.replace(/\D/g, '').slice(0, 6);
		if (pin.length === 6) handleUnlock();
	}
</script>

<div class="fixed inset-0 bg-md-surface z-[100] flex items-center justify-center" transition:fade={{ duration: 200 }}>
	<div class="w-full max-w-xs text-center p-6">
		<!-- Lock icon -->
		<div class="w-16 h-16 bg-md-primary-container rounded-full flex items-center justify-center mx-auto mb-4">
			<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" class="text-md-primary"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
		</div>

		<h2 class="text-xl font-bold text-md-on-surface mb-1">Layar Terkunci</h2>
		<p class="text-sm text-md-on-surface-variant mb-1">{authStore.user?.name}</p>
		<p class="text-xs text-md-on-surface-variant/60 mb-5">Masukkan PIN 6 digit</p>

		{#if error}
			<div class="p-2 rounded-lg bg-md-error-container text-md-on-error-container text-sm font-medium mb-3 animate-shake">{error}</div>
		{/if}

		<!-- PIN dots indicator -->
		<div class="flex justify-center gap-3 mb-4">
			{#each Array(6) as _, i}
				<div class="w-4 h-4 rounded-full transition-all duration-200 {i < pin.length ? 'bg-md-primary scale-110' : 'bg-md-outline-variant/40'}"></div>
			{/each}
		</div>

		<!-- Native input (triggers mobile keyboard) -->
		<input
			type="tel"
			inputmode="numeric"
			pattern="[0-9]*"
			maxlength="6"
			value={pin}
			oninput={handleInput}
			placeholder="● ● ● ● ● ●"
			disabled={loading}
			class="w-full h-14 px-4 rounded-xl bg-md-surface-container text-md-on-surface text-center text-2xl font-bold
				border-2 border-md-outline-variant focus:border-md-primary focus:outline-none focus:ring-2 focus:ring-md-primary/20
				tracking-[0.5em] transition-all mb-4 disabled:opacity-50"
			style="-webkit-text-security: disc;"
		/>

		{#if loading}
			<p class="text-sm text-md-on-surface-variant mb-4">Memverifikasi...</p>
		{/if}

		<button use:ripple class="w-full h-11 rounded-xl bg-md-error-container/50 text-md-error font-semibold text-sm hover:bg-md-error-container transition-colors" onclick={handleLogout}>
			Ganti Akun / Login Ulang
		</button>
	</div>
</div>

<style>
	@keyframes shake { 0%,100% { transform: translateX(0); } 20%,60% { transform: translateX(-6px); } 40%,80% { transform: translateX(6px); } }
	.animate-shake { animation: shake 0.4s ease-in-out; }
</style>
