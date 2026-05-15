<script lang="ts">
	import { goto } from '$app/navigation';
	import { ripple } from '$lib/actions/ripple';
	import ThemeToggle from '$lib/components/ThemeToggle.svelte';
	import { authStore } from '$lib/stores/auth.svelte';

	let username = $state('');
	let password = $state('');
	let error = $state('');
	let loading = $state(false);
	let showPassword = $state(false);

	async function handleLogin() {
		if (!username.trim() || !password) { error = 'Username dan password wajib'; return; }
		error = '';
		loading = true;
		try {
			const user = await authStore.login({ username: username.trim().toLowerCase(), password });
			authStore.persist();
			goto('/kasir');
		} catch (e: any) {
			error = e.message || 'Login gagal';
		}
		loading = false;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') handleLogin();
	}
</script>

<svelte:head><title>KAYPOS — Login</title></svelte:head>

<div class="min-h-screen bg-md-surface flex flex-col items-center justify-center p-4">
	<div class="absolute top-4 right-4"><ThemeToggle /></div>

	<!-- Logo -->
	<div class="mb-8 flex flex-col items-center">
		<div class="w-20 h-20 rounded-3xl bg-md-primary flex items-center justify-center mb-4 elevation-2">
			<span class="text-md-on-primary font-black text-4xl">K</span>
		</div>
		<h1 class="text-2xl font-extrabold text-md-on-surface tracking-tight">KAYPOS</h1>
		<p class="text-md-on-surface-variant text-sm mt-1">Sistem Point of Sale</p>
	</div>

	<!-- Login Form -->
	<div class="w-full max-w-sm space-y-4">
		{#if error}
			<div class="p-3 rounded-xl bg-md-error-container text-md-on-error-container text-sm font-medium text-center">{error}</div>
		{/if}

		<div>
			<label class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider mb-1.5 block" for="username">Username</label>
			<input id="username" type="text" bind:value={username} placeholder="Masukkan username"
				onkeydown={handleKeydown} autocomplete="username" autofocus
				class="w-full h-14 px-4 rounded-xl bg-md-surface-container text-md-on-surface text-base font-medium
					border-2 border-md-outline-variant focus:border-md-primary focus:outline-none focus:ring-2 focus:ring-md-primary/20 transition-all" />
		</div>

		<div>
			<label class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider mb-1.5 block" for="password">Password</label>
			<div class="relative">
				<input id="password" type={showPassword ? 'text' : 'password'} bind:value={password} placeholder="Masukkan password"
					onkeydown={handleKeydown} autocomplete="current-password"
					class="w-full h-14 px-4 pr-12 rounded-xl bg-md-surface-container text-md-on-surface text-base font-medium
						border-2 border-md-outline-variant focus:border-md-primary focus:outline-none focus:ring-2 focus:ring-md-primary/20 transition-all" />
				<button type="button" class="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 text-md-on-surface-variant hover:text-md-on-surface transition-colors" onclick={() => showPassword = !showPassword}>
					{#if showPassword}
						<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
					{:else}
						<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><line x1="2" x2="22" y1="2" y2="22"/></svg>
					{/if}
				</button>
			</div>
		</div>

		<button use:ripple disabled={loading}
			class="w-full h-14 rounded-2xl bg-md-primary text-md-on-primary font-bold text-lg elevation-1
				disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-95 transition-all active:scale-[0.98]"
			onclick={handleLogin}>
			{loading ? 'Memverifikasi...' : 'Masuk'}
		</button>

		<p class="text-center text-xs text-md-on-surface-variant/50 mt-6">Hubungi admin jika lupa password</p>
	</div>
</div>
