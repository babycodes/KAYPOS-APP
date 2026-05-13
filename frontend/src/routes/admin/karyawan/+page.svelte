<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';
	import { fade } from 'svelte/transition';

	let users = $state<any[]>([]);
	let showForm = $state(false);
	let form = $state({ username: '', name: '', password: '', role: 'kasir' });
	let formError = $state('');

	onMount(async () => { await load(); });
	async function load() { users = await api.get('/users'); }

	function openCreate() {
		form = { username: '', name: '', password: '', role: 'kasir' };
		formError = '';
		showForm = true;
	}

	async function save() {
		if (!form.username.trim() || !form.name.trim() || !form.password) {
			formError = 'Semua field wajib diisi';
			return;
		}
		try {
			await api.post('/users', form);
			showForm = false;
			await load();
		} catch (e: any) { formError = e.message; }
	}

	async function toggleActive(u: any) {
		await api.put(`/users/${u.id}`, { is_active: u.is_active ? 0 : 1 });
		await load();
	}

	async function resetPassword(u: any) {
		const newPw = prompt(`Reset password untuk ${u.name}?\nMasukkan password baru:`);
		if (!newPw) return;
		await api.put(`/users/${u.id}`, { password: newPw });
		alert('✅ Password berhasil direset!');
	}
</script>

<div class="space-y-4">
	<div class="flex justify-between items-center">
		<p class="text-sm text-md-on-surface-variant">{users.length} karyawan</p>
		<button use:ripple class="px-5 py-2.5 rounded-xl bg-md-primary text-md-on-primary font-semibold text-sm min-h-[44px] elevation-1" onclick={openCreate}>+ Tambah Karyawan</button>
	</div>

	<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
		{#each users as u (u.id)}
			<div class="p-4 rounded-2xl bg-md-surface-bright border border-md-outline-variant {u.is_active ? '' : 'opacity-40'}">
				<div class="flex items-center gap-3 mb-3">
					<div class="w-12 h-12 rounded-full {u.role === 'admin' ? 'bg-md-tertiary-container' : 'bg-md-primary-container'} flex items-center justify-center">
						<span class="text-lg font-bold {u.role === 'admin' ? 'text-md-on-tertiary-container' : 'text-md-on-primary-container'}">{u.name?.charAt(0)}</span>
					</div>
					<div class="flex-1">
						<div class="font-bold text-md-on-surface">{u.name}</div>
						<div class="text-xs text-md-on-surface-variant">@{u.username} · <span class="font-semibold uppercase {u.role === 'admin' ? 'text-md-tertiary' : 'text-md-primary'}">{u.role}</span></div>
					</div>
				</div>
				<div class="flex gap-2">
					<button use:ripple class="flex-1 py-2 rounded-lg text-xs font-semibold bg-md-surface-container text-md-on-surface hover:bg-md-surface-container-high transition-colors" onclick={() => resetPassword(u)}>🔑 Reset Password</button>
					{#if u.role !== 'admin'}
						<button use:ripple class="flex-1 py-2 rounded-lg text-xs font-semibold {u.is_active ? 'bg-md-error-container/50 text-md-error' : 'bg-md-secondary-container/50 text-md-secondary'}" onclick={() => toggleActive(u)}>
							{u.is_active ? '🚫 Nonaktifkan' : '✅ Aktifkan'}
						</button>
					{/if}
				</div>
			</div>
		{/each}
	</div>
</div>

{#if showForm}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" transition:fade={{ duration: 150 }} onclick={(e) => { if (e.target === e.currentTarget) showForm = false; }}>
		<div class="w-full max-w-sm bg-md-surface-bright rounded-2xl p-6 elevation-3">
			<h3 class="text-lg font-bold mb-4">Tambah Karyawan</h3>
			{#if formError}
				<div class="p-2 rounded-lg bg-md-error-container text-md-on-error-container text-sm font-medium mb-3">{formError}</div>
			{/if}
			<div class="space-y-3 mb-4">
				<div>
					<label class="text-xs font-semibold text-md-on-surface-variant block mb-1" for="emp-username">Username</label>
					<input id="emp-username" type="text" bind:value={form.username} placeholder="contoh: kasir3" class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
				</div>
				<div>
					<label class="text-xs font-semibold text-md-on-surface-variant block mb-1" for="emp-name">Nama Lengkap</label>
					<input id="emp-name" type="text" bind:value={form.name} placeholder="Nama karyawan" class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
				</div>
				<div>
					<label class="text-xs font-semibold text-md-on-surface-variant block mb-1" for="emp-pw">Password</label>
					<input id="emp-pw" type="text" bind:value={form.password} placeholder="Password awal" class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
				</div>
			</div>
			<div class="flex gap-3">
				<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold" onclick={() => showForm = false}>Batal</button>
				<button use:ripple class="flex-[2] h-12 rounded-xl bg-md-primary text-md-on-primary font-bold" onclick={save}>Simpan</button>
			</div>
		</div>
	</div>
{/if}
