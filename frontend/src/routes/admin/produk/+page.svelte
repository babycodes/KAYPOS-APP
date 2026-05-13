<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';
	import { fade } from 'svelte/transition';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';

	let products = $state<any[]>([]);
	let categories = $state<any[]>([]);
	let showForm = $state(false);
	let editId = $state<number | null>(null);
	let form = $state({ name: '', category_id: 0, barcode: '', stock: 0, min_stock: 0 });
	let unitPrices = $state<{ unit_name: string; qty_per_unit: number; price: number }[]>([]);
	let availableUnits = $state<string[]>([]);

	let activeTab = $state<'active' | 'inactive'>('active');
	let searchQuery = $state('');
	let currentPage = $state(1);
	const perPage = 10;
	let deleteTarget = $state<any | null>(null);

	onMount(async () => { await loadData(); });
	async function loadData() {
		[products, categories] = await Promise.all([api.get('/products/all'), api.get('/categories')]);
	}

	let filteredProducts = $derived(
		products.filter((p: any) => {
			const matchTab = activeTab === 'active' ? p.is_active : !p.is_active;
			const matchSearch = !searchQuery || p.name.toLowerCase().includes(searchQuery.toLowerCase())
				|| (p.barcode || '').toLowerCase().includes(searchQuery.toLowerCase())
				|| (p.category_name || '').toLowerCase().includes(searchQuery.toLowerCase());
			return matchTab && matchSearch;
		})
	);
	let totalPages = $derived(Math.max(1, Math.ceil(filteredProducts.length / perPage)));
	let pagedProducts = $derived(filteredProducts.slice((currentPage - 1) * perPage, currentPage * perPage));
	let activeCount = $derived(products.filter((p: any) => p.is_active).length);
	let inactiveCount = $derived(products.filter((p: any) => !p.is_active).length);

	$effect(() => { activeTab; searchQuery; currentPage = 1; });

	function onCategoryChange(catId: number) {
		form.category_id = catId;
		const cat = categories.find((c: any) => c.id === catId);
		availableUnits = (cat?.units || []).map((u: any) => u.unit_name);
		// Keep existing unit prices that match available units
		unitPrices = unitPrices.filter(u => availableUnits.includes(u.unit_name));
	}

	function addUnitPrice() {
		const unused = availableUnits.filter(u => !unitPrices.find(up => up.unit_name === u));
		if (unused.length > 0) {
			unitPrices = [...unitPrices, { unit_name: unused[0], qty_per_unit: 1, price: 0 }];
		}
	}

	function removeUnitPrice(i: number) { unitPrices = unitPrices.filter((_, idx) => idx !== i); }

	function openCreate() {
		editId = null;
		form = { name: '', category_id: categories[0]?.id || 0, barcode: '', stock: 0, min_stock: 0 };
		unitPrices = [];
		onCategoryChange(form.category_id);
		showForm = true;
	}

	function openEdit(p: any) {
		editId = p.id;
		form = { name: p.name, category_id: p.category_id, barcode: p.barcode || '', stock: p.stock_quantity, min_stock: 0 };
		const cat = categories.find((c: any) => c.id === p.category_id);
		availableUnits = (cat?.units || []).map((u: any) => u.unit_name);
		unitPrices = (p.units || []).map((u: any) => ({
			unit_name: u.unit_name, qty_per_unit: u.qty_per_unit || 1, price: u.price
		}));
		showForm = true;
	}

	async function saveProduct() {
		try {
			const data = { ...form, unit_prices: unitPrices.filter(u => u.price > 0) };
			if (editId) { await api.put(`/products/${editId}`, data); }
			else { await api.post('/products', data); }
			showForm = false; await loadData();
		} catch (e: any) { alert('Error: ' + e.message); }
	}

	async function toggleActive(p: any) {
		await api.put(`/products/${p.id}`, { is_active: p.is_active ? 0 : 1 });
		await loadData();
	}

	async function confirmDelete() {
		if (!deleteTarget) return;
		try { await api.del(`/products/${deleteTarget.id}`); deleteTarget = null; await loadData(); }
		catch (e: any) { alert('Error: ' + e.message); }
	}

	function fmtPrice(n: number) { return n < 1 && n > 0 ? `Rp ${n.toFixed(2)}` : `Rp ${Math.round(n).toLocaleString('id-ID')}`; }
	function getUnitInfo(p: any): string {
		if (!p.units?.length) return '-';
		return p.units.map((u: any) => `${u.qty_per_unit > 1 ? u.qty_per_unit : ''}${u.unit_name}=${fmtPrice(u.price)}`).join(', ');
	}
</script>

<div class="space-y-4">
	<div class="flex justify-between items-center flex-wrap gap-2">
		<div class="flex rounded-xl bg-md-surface-container p-1 border border-md-outline-variant/50">
			<button use:ripple class="px-4 py-2 rounded-lg text-sm font-semibold transition-all
				{activeTab === 'active' ? 'bg-md-primary text-md-on-primary shadow-sm' : 'text-md-on-surface-variant'}"
				onclick={() => activeTab = 'active'}>Aktif ({activeCount})</button>
			<button use:ripple class="px-4 py-2 rounded-lg text-sm font-semibold transition-all
				{activeTab === 'inactive' ? 'bg-md-error text-md-on-error shadow-sm' : 'text-md-on-surface-variant'}"
				onclick={() => activeTab = 'inactive'}>Nonaktif ({inactiveCount})</button>
		</div>
		<button use:ripple class="px-5 py-2.5 rounded-xl bg-md-primary text-md-on-primary font-semibold text-sm min-h-[44px] elevation-1" onclick={openCreate}>+ Tambah Produk</button>
	</div>

	<div class="relative max-w-md">
		<svg class="absolute left-3 top-1/2 -translate-y-1/2 text-md-on-surface-variant" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
		<input type="text" bind:value={searchQuery} placeholder="Cari nama, barcode, kategori..."
			class="w-full h-10 pl-10 pr-4 rounded-xl bg-md-surface-container text-sm text-md-on-surface border border-md-outline-variant/50 focus:border-md-primary focus:outline-none" />
	</div>

	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant overflow-hidden">
		<div class="overflow-x-auto">
			<table class="w-full text-sm">
				<thead><tr class="bg-md-surface-container text-md-on-surface-variant text-left">
					<th class="px-4 py-3 font-semibold">Nama</th>
					<th class="px-4 py-3 font-semibold">Kategori</th>
					<th class="px-4 py-3 font-semibold">Harga Satuan</th>
					<th class="px-4 py-3 font-semibold">Stok</th>
					<th class="px-4 py-3 font-semibold text-right">Aksi</th>
				</tr></thead>
				<tbody>
					{#each pagedProducts as p (p.id)}
						<tr class="border-t border-md-outline-variant/50 hover:bg-md-surface-container/30 transition-colors">
							<td class="px-4 py-3">
								<div class="font-medium">{p.name}</div>
								{#if p.barcode}<div class="text-[10px] text-md-on-surface-variant font-mono">{p.barcode}</div>{/if}
							</td>
							<td class="px-4 py-3 text-md-on-surface-variant">{p.category_icon} {p.category_name || '-'}</td>
							<td class="px-4 py-3">
								<div class="space-y-0.5">
									{#each (p.units || []) as u}
										<div class="text-xs">
											<span class="font-medium text-md-primary">{u.qty_per_unit > 1 ? u.qty_per_unit + ' ' : ''}{u.unit_name}</span>
											<span class="text-md-on-surface-variant"> = </span>
											<span class="font-semibold tabular-nums">{fmtPrice(u.price)}</span>
										</div>
									{/each}
								</div>
							</td>
							<td class="px-4 py-3 tabular-nums">{Math.round(p.stock_quantity)}</td>
							<td class="px-4 py-3 text-right">
								<div class="flex justify-end gap-1">
									<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-md-primary-container/50 text-md-primary" onclick={() => openEdit(p)}>Edit</button>
									<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold {p.is_active ? 'bg-md-surface-container text-md-on-surface-variant' : 'bg-md-secondary-container/50 text-md-secondary'}" onclick={() => toggleActive(p)}>
										{p.is_active ? 'Nonaktifkan' : 'Aktifkan'}
									</button>
									<button use:ripple class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-md-error-container/50 text-md-error" onclick={() => deleteTarget = p}>Hapus</button>
								</div>
							</td>
						</tr>
					{/each}
					{#if pagedProducts.length === 0}
						<tr><td colspan="5" class="px-4 py-8 text-center text-md-on-surface-variant">
							{searchQuery ? 'Tidak ditemukan' : activeTab === 'inactive' ? 'Tidak ada produk nonaktif' : 'Belum ada produk'}
						</td></tr>
					{/if}
				</tbody>
			</table>
		</div>
		{#if totalPages > 1}
			<div class="flex items-center justify-between px-4 py-3 border-t border-md-outline-variant/50">
				<span class="text-xs text-md-on-surface-variant">{(currentPage-1)*perPage+1}–{Math.min(currentPage*perPage, filteredProducts.length)} dari {filteredProducts.length}</span>
				<div class="flex gap-1">
					<button use:ripple disabled={currentPage<=1} class="w-8 h-8 rounded-lg text-xs font-bold flex items-center justify-center bg-md-surface-container disabled:opacity-30" onclick={() => currentPage--}>‹</button>
					{#each Array(totalPages) as _, i}
						<button use:ripple class="w-8 h-8 rounded-lg text-xs font-bold flex items-center justify-center {currentPage===i+1 ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container text-md-on-surface-variant'}" onclick={() => currentPage=i+1}>{i+1}</button>
					{/each}
					<button use:ripple disabled={currentPage>=totalPages} class="w-8 h-8 rounded-lg text-xs font-bold flex items-center justify-center bg-md-surface-container disabled:opacity-30" onclick={() => currentPage++}>›</button>
				</div>
			</div>
		{/if}
	</div>
</div>

<!-- Product Form -->
{#if showForm}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" transition:fade={{ duration: 150 }} onclick={(e) => { if (e.target === e.currentTarget) showForm = false; }}>
		<div class="w-full max-w-xl bg-md-surface-bright rounded-2xl p-6 elevation-3 max-h-[85vh] overflow-y-auto no-scrollbar">
			<h3 class="text-lg font-bold mb-4">{editId ? 'Edit' : 'Tambah'} Produk</h3>
			<div class="grid grid-cols-2 gap-3 mb-4">
				<div class="col-span-2">
					<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Nama Produk</label>
					<input type="text" bind:value={form.name} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
				</div>
				<div>
					<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Kategori</label>
					<select value={form.category_id} onchange={(e) => onCategoryChange(Number((e.target as HTMLSelectElement).value))} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface">
						{#each categories as c}<option value={c.id}>{c.icon} {c.name}</option>{/each}
					</select>
				</div>
				<div>
					<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Barcode</label>
					<input type="text" bind:value={form.barcode} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
				</div>
				{#if !editId}
					<div>
						<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Stok Awal</label>
						<input type="number" bind:value={form.stock} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
					</div>
					<div>
						<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Min. Stok Alert</label>
						<input type="number" bind:value={form.min_stock} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" />
					</div>
				{/if}
			</div>

			<!-- Unit Prices -->
			<div class="mb-4 p-4 rounded-xl bg-md-primary-container/10 border border-md-primary/20">
				<div class="flex justify-between items-center mb-2">
					<h4 class="text-xs font-semibold text-md-on-surface-variant uppercase tracking-wider">💰 Harga per Satuan</h4>
					{#if availableUnits.filter(u => !unitPrices.find(up => up.unit_name === u)).length > 0}
						<button use:ripple class="text-xs font-semibold text-md-primary px-3 py-1 rounded-lg hover:bg-md-primary-container/30" onclick={addUnitPrice}>+ Tambah Satuan</button>
					{/if}
				</div>
				<p class="text-[11px] text-md-on-surface-variant/70 mb-3">Pilih satuan dari dropdown, isi jumlah dan harga. Contoh: 250 gram = Rp1000</p>

				{#if unitPrices.length === 0}
					<p class="text-sm text-md-on-surface-variant/50 text-center py-3">Belum ada harga. Klik "+ Tambah Satuan" untuk menambah.</p>
				{:else}
					<div class="space-y-2">
						<!-- Header -->
						<div class="grid grid-cols-[1fr_80px_1fr_36px] gap-2 text-[10px] font-semibold text-md-on-surface-variant uppercase">
							<span>Satuan</span><span>Jumlah</span><span>Harga (Rp)</span><span></span>
						</div>
						{#each unitPrices as unit, i}
							<div class="grid grid-cols-[1fr_80px_1fr_36px] gap-2 items-center">
								<select bind:value={unit.unit_name} class="h-10 px-3 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface">
									{#each availableUnits as au}
										{#if au === unit.unit_name || !unitPrices.find(up => up.unit_name === au)}
											<option value={au}>{au}</option>
										{/if}
									{/each}
								</select>
								<input type="number" bind:value={unit.qty_per_unit} min="0.01" step="any"
									class="h-10 px-2 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface text-center tabular-nums focus:border-md-primary focus:outline-none" />
								<input type="number" bind:value={unit.price} min="0" step="any"
									class="h-10 px-2 rounded-lg bg-md-surface-container border border-md-outline-variant text-sm text-md-on-surface text-right tabular-nums font-semibold focus:border-md-primary focus:outline-none" />
								<button use:ripple class="w-9 h-10 rounded-lg bg-md-error-container/50 text-md-error flex items-center justify-center text-xs" onclick={() => removeUnitPrice(i)}>✕</button>
							</div>
						{/each}
					</div>
				{/if}
			</div>

			<div class="flex gap-3">
				<button use:ripple class="flex-1 h-12 rounded-xl bg-md-surface-container text-md-on-surface font-semibold" onclick={() => showForm = false}>Batal</button>
				<button use:ripple class="flex-[2] h-12 rounded-xl bg-md-primary text-md-on-primary font-bold" onclick={saveProduct}>Simpan</button>
			</div>
		</div>
	</div>
{/if}

{#if deleteTarget}
	<ConfirmDialog title="Hapus Produk" message="Produk '{deleteTarget.name}' akan dihapus permanen. Aksi ini tidak bisa dibatalkan."
		confirmText="Hapus Permanen" onConfirm={confirmDelete} onCancel={() => deleteTarget = null} />
{/if}
