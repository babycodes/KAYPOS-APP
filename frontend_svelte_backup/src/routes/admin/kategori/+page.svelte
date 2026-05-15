<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';
	import { fade } from 'svelte/transition';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';

	let categories = $state<any[]>([]);
	let showForm = $state(false);
	let editId = $state<number | null>(null);
	let form = $state({ name: '', icon: '📦', sort_order: 0 });
	let formUnits = $state<string[]>([]);
	let newUnit = $state('');
	let deleteTarget = $state<any | null>(null);
	let deleteForce = $state(false);

	onMount(async () => { await load(); });
	async function load() { categories = await api.get('/categories'); }

	function openCreate() {
		editId = null;
		form = { name: '', icon: '📦', sort_order: 0 };
		formUnits = ['pcs'];
		newUnit = '';
		showForm = true;
	}

	function openEdit(c: any) {
		editId = c.id;
		form = { name: c.name, icon: c.icon, sort_order: c.sort_order };
		formUnits = (c.units || []).map((u: any) => u.unit_name);
		newUnit = '';
		showForm = true;
	}

	function addUnit() {
		const u = newUnit.trim().toLowerCase();
		if (u && !formUnits.includes(u)) { formUnits = [...formUnits, u]; }
		newUnit = '';
	}

	function removeUnit(i: number) { formUnits = formUnits.filter((_, idx) => idx !== i); }

	async function save() {
		if (!form.name.trim()) return;
		try {
			const data = { ...form, units: formUnits.filter(u => u.trim()) };
			if (editId) { await api.put(`/categories/${editId}`, data); }
			else { await api.post('/categories', data); }
			showForm = false; await load();
		} catch (e: any) { alert('Error: ' + e.message); }
	}

	function requestDelete(cat: any) {
		deleteTarget = cat;
		deleteForce = (cat.product_count || 0) > 0;
	}

	async function confirmDelete() {
		if (!deleteTarget) return;
		try {
			const url = deleteForce ? `/categories/${deleteTarget.id}?force=1` : `/categories/${deleteTarget.id}`;
			await api.del(url);
			deleteTarget = null;
			await load();
		} catch (e: any) { alert('Error: ' + e.message); }
	}

	const emojis = ['📦','🛍️','🧱','🏠','🏪','🔧','🎨','🧴','💡','🔩','🪵','🧲','🪣','🧹','🛠️','⚡','🍚','🍜','🍞','🥩','🐟','🥗','🍰','🧁','🍩','☕','🥤','🧃','🍫','🧀','🥚','🌶️','🧅','🍎','🥕','🫘'];
</script>

<div class="space-y-4">
	<div class="flex justify-between items-center">
		<p class="text-sm text-md-on-surface-variant">{categories.length} kategori</p>
		<button use:ripple class="px-5 py-2.5 rounded-xl bg-md-primary text-md-on-primary font-semibold text-sm min-h-[44px] elevation-1" onclick={openCreate}>+ Tambah Kategori</button>
	</div>

	<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
		{#each categories as cat (cat.id)}
			<div class="p-4 rounded-2xl bg-md-surface-bright border border-md-outline-variant hover:border-md-primary/30 transition-all">
				<div class="flex items-center justify-between mb-2">
					<div class="flex items-center gap-3">
						<span class="text-3xl">{cat.icon}</span>
						<div>
							<div class="font-bold text-md-on-surface">{cat.name}</div>
							<div class="text-xs text-md-on-surface-variant">{cat.product_count || 0} produk</div>
						</div>
					</div>
					<div class="flex gap-1">
						<button use:ripple class="w-9 h-9 rounded-lg bg-md-primary-container/50 text-md-primary flex items-center justify-center text-sm" onclick={() => openEdit(cat)}>✏️</button>
						<button use:ripple class="w-9 h-9 rounded-lg bg-md-error-container/50 text-md-error flex items-center justify-center text-sm" onclick={() => requestDelete(cat)}>🗑️</button>
					</div>
				</div>
				{#if cat.units?.length}
					<div class="flex flex-wrap gap-1.5 mt-2">
						{#each cat.units as u}
							<span class="text-[11px] px-2 py-0.5 rounded-full bg-md-tertiary-container/50 text-md-on-tertiary-container font-medium">{u.unit_name}</span>
						{/each}
					</div>
				{/if}
			</div>
		{/each}
	</div>
</div>

<!-- Form Modal -->
{#if showForm}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" transition:fade={{ duration: 150 }} onclick={(e) => { if (e.target === e.currentTarget) showForm = false; }}>
		<div class="w-full max-w-lg bg-md-surface-bright rounded-2xl p-6 elevation-3 max-h-[85vh] overflow-y-auto no-scrollbar">
			<h3 class="text-lg font-bold mb-4">{editId ? 'Edit' : 'Tambah'} Kategori</h3>

			<div class="mb-3">
				<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Nama</label>
				<input type="text" bind:value={form.name} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
			</div>

			<div class="mb-3">
				<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Icon</label>
				<div class="flex flex-wrap gap-2">
					{#each emojis as emoji}
						<button class="w-10 h-10 rounded-lg text-xl flex items-center justify-center transition-all {form.icon === emoji ? 'bg-md-primary-container ring-2 ring-md-primary' : 'bg-md-surface-container hover:bg-md-surface-container-high'}" onclick={() => form.icon = emoji}>{emoji}</button>
					{/each}
				</div>
			</div>

			<div class="mb-4">
				<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Urutan</label>
				<input type="number" bind:value={form.sort_order} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
			</div>

			<!-- Unit Names -->
			<div class="mb-4 p-4 rounded-xl bg-md-surface-container/50 border border-md-outline-variant/50">
				<label class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider block mb-2">📏 Satuan yang Tersedia</label>
				<p class="text-[11px] text-md-on-surface-variant/70 mb-3">Tambahkan nama satuan. Harga ditentukan saat menambahkan produk.</p>

				<div class="flex flex-wrap gap-2 mb-3">
					{#each formUnits as unit, i}
						<span class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-md-primary-container text-md-on-primary-container text-sm font-medium">
							{unit}
							<button class="ml-1 w-4 h-4 rounded-full bg-md-on-primary-container/20 flex items-center justify-center text-[10px] hover:bg-md-error hover:text-white transition-colors" onclick={() => removeUnit(i)}>✕</button>
						</span>
					{/each}
				</div>

				<div class="flex gap-2">
					<input type="text" bind:value={newUnit} placeholder="Ketik nama satuan..." 
						onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addUnit(); }}}
						class="flex-1 h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface focus:border-md-primary focus:outline-none" />
					<button use:ripple class="px-4 h-10 rounded-lg bg-md-primary text-md-on-primary text-sm font-semibold" onclick={addUnit}>Tambah</button>
				</div>
			</div>

			<div class="flex gap-3">
				<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold" onclick={() => showForm = false}>Batal</button>
				<button use:ripple class="flex-[2] h-12 rounded-xl bg-md-primary text-md-on-primary font-bold" onclick={save}>Simpan</button>
			</div>
		</div>
	</div>
{/if}

{#if deleteTarget}
	<ConfirmDialog
		title="Hapus Kategori"
		message={deleteForce
			? `Kategori "${deleteTarget.name}" memiliki ${deleteTarget.product_count} produk. Menghapus kategori ini akan menghapus SEMUA produk yang terkait. Aksi ini tidak bisa dibatalkan.`
			: `Hapus kategori "${deleteTarget.name}"?`}
		confirmText={deleteForce ? `Hapus Semua (${deleteTarget.product_count} produk)` : 'Hapus'}
		onConfirm={confirmDelete}
		onCancel={() => deleteTarget = null} />
{/if}
