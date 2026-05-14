<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';
	import { fade } from 'svelte/transition';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';

	let users = $state<any[]>([]);
	let showForm = $state(false);
	let form = $state({ username: '', name: '' });
	let formError = $state('');
	let deleteTarget = $state<any | null>(null);
	let resetTarget = $state<any | null>(null);

	onMount(async () => { await load(); });
	async function load() { users = await api.get('/users'); }

	function openCreate() {
		form = { username: '', name: '' };
		formError = '';
		showForm = true;
	}

	async function save() {
		if (!form.username.trim() || !form.name.trim()) {
			formError = 'Username dan nama wajib diisi';
			return;
		}
		try {
			await api.post('/users', { ...form, role: 'kasir' });
			showForm = false;
			await load();
		} catch (e: any) { formError = e.message; }
	}

	async function toggleActive(u: any) {
		await api.put(`/users/${u.id}`, { is_active: u.is_active ? 0 : 1 });
		await load();
	}

	async function confirmReset() {
		if (!resetTarget) return;
		try {
			await api.post(`/users/${resetTarget.id}/reset`);
			resetTarget = null;
		} catch (e: any) { alert('Error: ' + e.message); }
	}

	async function confirmDelete() {
		if (!deleteTarget) return;
		try {
			await api.del(`/users/${deleteTarget.id}`);
			deleteTarget = null;
			await load();
		} catch (e: any) { alert('Error: ' + e.message); }
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
					<div class="w-12 h-12 rounded-full {u.role === 'admin' ? 'bg-md-tertiary-container' : 'bg-md-primary-container'} flex items-center justify-center shrink-0">
						<span class="text-lg font-bold {u.role === 'admin' ? 'text-md-on-tertiary-container' : 'text-md-on-primary-container'}">{u.name?.charAt(0)}</span>
					</div>
					<div class="flex-1 min-w-0">
						<div class="font-bold text-md-on-surface truncate">{u.name}</div>
						<div class="text-xs text-md-on-surface-variant">@{u.username} · <span class="font-semibold uppercase {u.role === 'admin' ? 'text-md-tertiary' : 'text-md-primary'}">{u.role}</span></div>
					</div>
				</div>
				<div class="flex flex-wrap gap-1.5">
					<button use:ripple class="flex-1 py-2 rounded-lg text-[11px] font-semibold bg-md-surface-container text-md-on-surface hover:bg-md-surface-container-high transition-colors flex items-center justify-center gap-1" onclick={() => resetTarget = u}>
						<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.2-8.6"/></svg>
						Reset PW & PIN
					</button>
					{#if u.role !== 'admin'}
						<button use:ripple class="py-2 px-3 rounded-lg text-[11px] font-semibold {u.is_active ? 'bg-md-error-container/50 text-md-error' : 'bg-md-secondary-container/50 text-md-secondary'}" onclick={() => toggleActive(u)}>
							{u.is_active ? 'Nonaktifkan' : 'Aktifkan'}
						</button>
						<button use:ripple class="py-2 px-3 rounded-lg text-[11px] font-semibold bg-md-error text-md-on-error" onclick={() => deleteTarget = u}>
							<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
						</button>
					{/if}
				</div>
			</div>
		{/each}
	</div>
</div>

<!-- Add Form -->
{#if showForm}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-end md:items-center justify-center" transition:fade={{ duration: 150 }} onclick={(e) => { if (e.target === e.currentTarget) showForm = false; }}>
		<div class="w-full max-w-sm bg-md-surface-bright rounded-t-2xl md:rounded-2xl p-6 elevation-3">
			<h3 class="text-lg font-bold mb-1">Tambah Karyawan</h3>
			<p class="text-xs text-md-on-surface-variant mb-4">Password default: <span class="font-mono font-bold">pwkasir</span> · PIN: <span class="font-mono font-bold">000000</span></p>
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
			</div>
			<div class="flex gap-3">
				<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold" onclick={() => showForm = false}>Batal</button>
				<button use:ripple class="flex-[2] h-12 rounded-xl bg-md-primary text-md-on-primary font-bold" onclick={save}>Simpan</button>
			</div>
		</div>
	</div>
{/if}

<!-- Reset Confirmation -->
{#if resetTarget}
	<ConfirmDialog
		title="Reset Password & PIN"
		message="Yakin ingin mereset password dan PIN untuk '{resetTarget.name}'? Password akan kembali ke 'pwkasir' dan PIN ke '000000'."
		confirmText="Ya, Reset"
		onConfirm={confirmReset}
		onCancel={() => resetTarget = null}
	/>
{/if}

<!-- Delete Confirmation -->
{#if deleteTarget}
	<ConfirmDialog
		title="Hapus Karyawan"
		message="Karyawan '{deleteTarget.name}' akan dihapus permanen. Aksi ini tidak bisa dibatalkan."
		confirmText="Hapus Permanen"
		onConfirm={confirmDelete}
		onCancel={() => deleteTarget = null}
	/>
{/if}
