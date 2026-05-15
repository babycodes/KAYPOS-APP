<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { authStore } from '$lib/stores/auth.svelte';
	import { api } from '$lib/api';
	import ThemeToggle from '$lib/components/ThemeToggle.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';

	let { children } = $props();
	let accessDenied = $state(false);
	let checked = $state(false);
	let sidebarOpen = $state(false);
	let isMobile = $state(false);
	let lowStockCount = $state(0);
	let outOfStockCount = $state(0);
	let showLogoutConfirm = $state(false);

	function checkMobile() { isMobile = window.innerWidth < 768; }

	onMount(() => {
		if (!authStore.isLoggedIn && !authStore.restore()) {
			accessDenied = true;
			checked = true;
			return;
		}
		if (!authStore.isAdmin) {
			accessDenied = true;
			checked = true;
			return;
		}
		checked = true;
		checkMobile();
		sidebarOpen = !isMobile;
		window.addEventListener('resize', checkMobile);
		// Load stock counts
		Promise.all([api.get('/inventory/low-stock'), api.get('/inventory/out-of-stock')])
			.then(([low, empty]: [any[], any[]]) => { lowStockCount = low.length; outOfStockCount = empty.length; })
			.catch(() => {});
		return () => window.removeEventListener('resize', checkMobile);
	});

	const navItems = [
		{ href: '/admin', label: 'Dashboard', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/></svg>` },
		{ href: '/admin/produk', label: 'Produk', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m7.5 4.27 9 5.15"/><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/></svg>` },
		{ href: '/admin/kategori', label: 'Kategori', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2H2v10l9.29 9.29c.94.94 2.48.94 3.42 0l6.58-6.58c.94-.94.94-2.48 0-3.42L12 2Z"/><path d="M7 7h.01"/></svg>` },
		{ href: '/admin/stok', label: 'Inventaris', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5H2v7l6.29 6.29c.94.94 2.48.94 3.42 0l3.58-3.58c.94-.94.94-2.48 0-3.42L9 5Z"/><path d="M6 9.01V9"/><path d="m15 5 6.3 6.3a2.4 2.4 0 0 1 0 3.4L17 19"/></svg>` },
		{ href: '/admin/laporan', label: 'Laporan', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>` },
		{ href: '/admin/karyawan', label: 'Karyawan', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>` },
		{ href: '/admin/settings', label: 'Pengaturan', icon: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>` },
	];

	function handleNavClick() { if (isMobile) sidebarOpen = false; }
</script>

{#if !checked}
	<div class="min-h-screen bg-md-surface flex items-center justify-center">
		<div class="w-12 h-12 rounded-2xl bg-md-primary flex items-center justify-center animate-pulse">
			<span class="text-md-on-primary font-black text-lg">K</span>
		</div>
	</div>
{:else if accessDenied}
	<!-- Beautiful 404 Page -->
	<div class="min-h-screen bg-md-surface flex items-center justify-center relative overflow-hidden">
		<!-- Background decoration -->
		<div class="absolute inset-0 overflow-hidden opacity-5">
			<div class="absolute -top-20 -right-20 w-96 h-96 rounded-full bg-md-primary"></div>
			<div class="absolute -bottom-32 -left-32 w-[500px] h-[500px] rounded-full bg-md-tertiary"></div>
		</div>

		<div class="text-center max-w-md p-8 relative z-10">
			<!-- Animated 404 -->
			<div class="relative mb-8">
				<div class="text-[120px] font-black text-md-on-surface/5 leading-none select-none">404</div>
				<div class="absolute inset-0 flex items-center justify-center">
					<div class="w-24 h-24 rounded-3xl bg-md-error-container/50 flex items-center justify-center backdrop-blur-sm border border-md-error/20">
						<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="text-md-error">
							<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/></svg>
					</div>
				</div>
			</div>

			<h1 class="text-2xl font-extrabold text-md-on-surface mb-2">Halaman Tidak Ditemukan</h1>
			<p class="text-md-on-surface-variant text-sm mb-8 leading-relaxed">
				Halaman yang Anda cari tidak ada atau Anda tidak memiliki akses ke halaman ini.
			</p>

			<div class="flex flex-col sm:flex-row gap-3 justify-center">
				{#if authStore.isLoggedIn}
					<a href="/kasir" use:ripple class="inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl bg-md-primary text-md-on-primary font-bold text-sm elevation-1 hover:opacity-95 transition-all active:scale-[0.98]">
						<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/></svg>
						Kembali ke Kasir
					</a>
				{:else}
					<a href="/login" use:ripple class="inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl bg-md-primary text-md-on-primary font-bold text-sm elevation-1 hover:opacity-95 transition-all active:scale-[0.98]">
						🔐 Login
					</a>
				{/if}
			</div>
		</div>
	</div>
{:else}
	<div class="flex h-screen bg-md-surface text-md-on-surface overflow-hidden">
		<!-- Mobile overlay backdrop -->
		{#if isMobile && sidebarOpen}
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="fixed inset-0 bg-black/50 z-40 md:hidden" onclick={() => sidebarOpen = false}></div>
		{/if}

		<!-- Sidebar -->
		<aside class="
			{isMobile ? 'fixed inset-y-0 left-0 z-50 w-72' : sidebarOpen ? 'w-60' : 'w-16'}
			bg-md-surface-bright border-r border-md-outline-variant flex flex-col transition-all duration-300 overflow-hidden shrink-0
			{isMobile && !sidebarOpen ? '-translate-x-full' : 'translate-x-0'}
		">
			<div class="p-3 border-b border-md-outline-variant flex items-center gap-3 min-h-[64px]">
				<button use:ripple class="w-10 h-10 rounded-xl bg-md-primary flex items-center justify-center shrink-0" onclick={() => sidebarOpen = !sidebarOpen}>
					<span class="text-md-on-primary font-black text-sm">K</span>
				</button>
				{#if sidebarOpen || isMobile}
					<div class="overflow-hidden">
						<div class="font-extrabold text-md-on-surface">KAYPOS</div>
						<div class="text-[10px] text-md-on-surface-variant">Admin Panel</div>
					</div>
				{/if}
			</div>

			<nav class="flex-1 p-2 space-y-1 overflow-y-auto no-scrollbar">
				{#each navItems as item}
					{@const active = $page.url.pathname === item.href}
					<a href={item.href} use:ripple onclick={handleNavClick}
						class="flex items-center gap-3 px-3 py-2.5 rounded-xl font-medium text-sm min-h-[44px] transition-all
						{active ? 'bg-md-primary-container text-md-on-primary-container' : 'text-md-on-surface-variant hover:bg-md-surface-container'}">
						<span class="shrink-0 flex items-center justify-center w-5 h-5">{@html item.icon}</span>
						{#if sidebarOpen || isMobile}<span class="truncate flex-1">{item.label}</span>{/if}
						{#if item.label === 'Inventaris' && (lowStockCount > 0 || outOfStockCount > 0)}
							<span class="ml-auto flex gap-1">
								{#if outOfStockCount > 0}<span class="px-1.5 py-0.5 rounded-full bg-md-error text-md-on-error text-[10px] font-bold min-w-[18px] text-center leading-tight">{outOfStockCount}</span>{/if}
								{#if lowStockCount > 0}<span class="px-1.5 py-0.5 rounded-full bg-amber-500 text-white text-[10px] font-bold min-w-[18px] text-center leading-tight">{lowStockCount}</span>{/if}
							</span>
						{/if}
					</a>
				{/each}
			</nav>

			<div class="p-2 border-t border-md-outline-variant space-y-1">
				<a href="/kasir" use:ripple onclick={handleNavClick} class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-md-primary hover:bg-md-primary-container/30 min-h-[44px]">
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/></svg>
					{#if sidebarOpen || isMobile}<span>Ke Kasir</span>{/if}
				</a>
				<button use:ripple class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-md-error hover:bg-md-error-container/30 min-h-[44px]" onclick={() => showLogoutConfirm = true}>
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/></svg>
					{#if sidebarOpen || isMobile}<span>Logout</span>{/if}
				</button>
			</div>
		</aside>

		<div class="flex-1 flex flex-col overflow-hidden">
			<header class="px-4 md:px-6 py-3 bg-md-surface-bright border-b border-md-outline-variant flex items-center justify-between min-h-[64px] shrink-0 gap-3" style="padding-top: max(env(safe-area-inset-top, 0px), 12px)">
				<!-- Mobile hamburger -->
				<button use:ripple class="md:hidden w-10 h-10 rounded-xl bg-md-surface-container flex items-center justify-center shrink-0" onclick={() => sidebarOpen = true}>
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="18" y2="18"/></svg>
				</button>
				<div class="flex-1 min-w-0">
					<h1 class="text-lg font-bold text-md-on-surface truncate">
						{navItems.find(n => $page.url.pathname === n.href)?.label || 'Admin'}
					</h1>
					{#if authStore.user}
						<p class="text-xs text-md-on-surface-variant">Halo, {authStore.user.name}</p>
					{/if}
				</div>
				<ThemeToggle />
			</header>

			<main class="flex-1 overflow-y-auto p-4 md:p-6 no-scrollbar">
				{@render children()}
			</main>
		</div>
	</div>

	{#if showLogoutConfirm}
		<ConfirmDialog title="Logout" message="Yakin ingin logout dari admin panel?" confirmText="Ya, Logout" onConfirm={() => { authStore.logout(); goto('/login'); }} onCancel={() => showLogoutConfirm = false} />
	{/if}
{/if}
