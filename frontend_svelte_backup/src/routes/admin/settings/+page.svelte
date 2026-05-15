<script lang="ts">
	import { onMount } from 'svelte';
	import { ripple } from '$lib/actions/ripple';
	import { api } from '$lib/api';

	let settings = $state<Record<string, string>>({});
	let restoreFile = $state<File | null>(null);
	let saving = $state(false);
	let restoreMsg = $state('');
	let detectedPrinters = $state<{ path: string; name: string; writable: boolean }[]>([]);
	let detecting = $state(false);
	let testMsg = $state('');

	onMount(async () => {
		try { settings = await api.get('/backup/settings'); } catch {}
		detectPrinters();
	});

	async function detectPrinters() {
		detecting = true;
		try {
			const res = await api.get('/print/detect');
			detectedPrinters = res.printers || [];
			if (res.current) settings.printer_port = res.current;
		} catch { detectedPrinters = []; }
		detecting = false;
	}

	function selectPrinter(path: string) {
		settings.printer_port = path;
	}

	async function testPrint() {
		testMsg = '';
		try {
			const res = await api.post('/print/test');
			testMsg = '✅ ' + (res.message || 'Test print berhasil!');
		} catch (e: any) {
			testMsg = '❌ ' + e.message;
		}
	}

	async function saveSettings() {
		saving = true;
		try { await api.put('/backup/settings', settings); alert('✅ Pengaturan tersimpan'); }
		catch (e: any) { alert('Error: ' + e.message); }
		saving = false;
	}

	async function downloadBackup() {
		try { await api.downloadBackup(); } catch (e: any) { alert('Error: ' + e.message); }
	}

	async function restoreDB() {
		if (!restoreFile) return;
		if (!confirm('⚠️ Ini akan mengganti semua data dengan file backup. Lanjutkan?')) return;
		const fd = new FormData();
		fd.append('database', restoreFile);
		try {
			const res = await fetch(`http://${window.location.hostname}:3000/api/backup/restore`, {
				method: 'POST', headers: { 'Authorization': `Bearer ${localStorage.getItem('kaypos-token')}` }, body: fd
			});
			const data = await res.json();
			restoreMsg = data.message || 'Berhasil! Restart server.';
		} catch (e: any) { restoreMsg = 'Error: ' + e.message; }
	}
</script>

<div class="space-y-6 max-w-2xl">
	<!-- Store Info -->
	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-5">
		<h3 class="font-bold text-md-on-surface mb-4 flex items-center gap-2">
			<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="m2 7 4.41-4.41A2 2 0 0 1 7.83 2h8.34a2 2 0 0 1 1.42.59L22 7"/><path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><path d="M15 22v-4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v4"/><path d="M2 7h20"/><path d="M22 7v3a2 2 0 0 1-2 2a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 16 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 12 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 8 12a2.7 2.7 0 0 1-1.59-.63.7.7 0 0 0-.82 0A2.7 2.7 0 0 1 4 12a2 2 0 0 1-2-2V7"/></svg>
			Info Toko
		</h3>
		<div class="space-y-3">
			<div><label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Nama Toko (untuk struk)</label><input type="text" bind:value={settings.store_name} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" /></div>
			<div><label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Alamat</label><input type="text" bind:value={settings.store_address} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" /></div>
			<div><label class="text-xs font-semibold text-md-on-surface-variant block mb-1">No. Telp</label><input type="text" bind:value={settings.store_phone} class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none" /></div>
		</div>
	</div>

	<!-- Printer -->
	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-5">
		<div class="flex items-center justify-between mb-4">
			<h3 class="font-bold text-md-on-surface flex items-center gap-2">
				<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect width="12" height="8" x="6" y="14"/></svg>
				Printer Thermal
			</h3>
			<button use:ripple class="h-8 px-3 rounded-lg bg-md-secondary-container text-md-on-secondary-container text-xs font-bold flex items-center gap-1.5 {detecting ? 'opacity-50' : ''}" onclick={detectPrinters} disabled={detecting}>
				<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="{detecting ? 'animate-spin' : ''}"><path d="M21 12a9 9 0 1 1-6.2-8.6"/></svg>
				{detecting ? 'Mendeteksi...' : 'Deteksi Ulang'}
			</button>
		</div>

		<!-- Detected printers list -->
		{#if detectedPrinters.length > 0}
			<div class="mb-4 space-y-2">
				<p class="text-xs font-semibold text-md-on-surface-variant mb-2">Printer terdeteksi:</p>
				{#each detectedPrinters as p}
					{@const isActive = settings.printer_port === p.path}
					<button use:ripple class="w-full p-3 rounded-xl text-left transition-all flex items-center gap-3
						{isActive ? 'bg-md-primary-container border-2 border-md-primary' : 'bg-md-surface-container border border-md-outline-variant/30 hover:bg-md-surface-container-high'}" onclick={() => selectPrinter(p.path)}>
						<div class="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 {isActive ? 'bg-md-primary text-md-on-primary' : 'bg-md-surface-container-high text-md-on-surface-variant'}">
							<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect width="12" height="8" x="6" y="14"/></svg>
						</div>
						<div class="flex-1 min-w-0">
							<div class="font-semibold text-sm text-md-on-surface truncate">{p.name}</div>
							<div class="text-[10px] text-md-on-surface-variant font-mono">{p.path}</div>
						</div>
						<div class="flex items-center gap-2 shrink-0">
							{#if p.writable}
								<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-green-500/10 text-green-600">OK</span>
							{:else}
								<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-md-error-container text-md-error">No Access</span>
							{/if}
							{#if isActive}
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="text-md-primary"><path d="M20 6 9 17l-5-5"/></svg>
							{/if}
						</div>
					</button>
				{/each}
			</div>
		{:else if !detecting}
			<div class="mb-4 p-4 rounded-xl bg-md-surface-container text-center">
				<p class="text-sm text-md-on-surface-variant">Tidak ada printer terdeteksi</p>
				<p class="text-xs text-md-on-surface-variant/60 mt-1">Hubungkan printer USB lalu tekan "Deteksi Ulang"</p>
			</div>
		{/if}

		<!-- Manual port input -->
		<div class="mb-3">
			<label class="text-xs font-semibold text-md-on-surface-variant block mb-1">Port Printer (manual)</label>
			<input type="text" bind:value={settings.printer_port} placeholder="/dev/usb/lp0" class="w-full h-12 px-4 rounded-xl bg-md-surface-container border border-md-outline-variant text-md-on-surface focus:border-md-primary focus:outline-none font-mono text-sm" />
		</div>

		<!-- Test print -->
		<button use:ripple class="w-full py-2.5 rounded-xl bg-md-tertiary-container text-md-on-tertiary-container font-bold text-sm flex items-center justify-center gap-2" onclick={testPrint}>
			<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect width="12" height="8" x="6" y="14"/></svg>
			Test Print
		</button>
		{#if testMsg}
			<p class="mt-2 text-sm font-medium text-center {testMsg.startsWith('✅') ? 'text-green-600' : 'text-md-error'}">{testMsg}</p>
		{/if}
	</div>

	<button use:ripple class="w-full py-3 rounded-xl bg-md-primary text-md-on-primary font-bold elevation-1 {saving ? 'opacity-50' : ''}" onclick={saveSettings} disabled={saving}>
		{saving ? 'Menyimpan...' : '💾 Simpan Pengaturan'}
	</button>

	<!-- Backup & Restore -->
	<div class="rounded-2xl bg-md-surface-bright border border-md-outline-variant p-5">
		<h3 class="font-bold text-md-on-surface mb-4 flex items-center gap-2">
			<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/></svg>
			Backup & Restore
		</h3>

		<button use:ripple class="w-full py-3 rounded-xl bg-md-secondary-container text-md-on-secondary-container font-bold mb-4" onclick={downloadBackup}>
			📥 Download Backup ke Perangkat Ini
		</button>

		<div class="border-t border-md-outline-variant pt-4">
			<p class="text-xs text-md-on-surface-variant mb-2">Upload file .db untuk restore:</p>
			<input type="file" accept=".db" onchange={(e) => restoreFile = (e.target as HTMLInputElement).files?.[0] || null}
				class="w-full text-sm text-md-on-surface file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:bg-md-surface-container file:text-md-on-surface file:font-semibold" />
			{#if restoreFile}
				<button use:ripple class="w-full mt-3 py-3 rounded-xl bg-md-error text-md-on-error font-bold" onclick={restoreDB}>
					⚠️ Restore Database
				</button>
			{/if}
			{#if restoreMsg}
				<p class="mt-2 text-sm font-medium text-md-primary">{restoreMsg}</p>
			{/if}
		</div>
	</div>
</div>
