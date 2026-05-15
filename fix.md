# Fix untuk Release KAYPOS-FLUTTER - Status 403

## 🔴 Masalah
Release workflow gagal dengan error **403 Forbidden** saat mencoba membuat GitHub release menggunakan `softprops/action-gh-release@v1`.

```
⚠️ GitHub release failed with status: 403
❌ Too many retries. Aborting...
```

## ✅ Solusi

### Masalah Utama
Workflow tidak memiliki permission yang cukup untuk menulis ke GitHub releases. Error 403 menunjukkan akses ditolak.

### Perubahan yang Dilakukan

1. **Tambah Permissions di Top-Level** (baris 8-10)
```yaml
permissions:
  contents: write
  actions: read
```

2. **Tambah Permissions di Release Job** (baris 113-114)
```yaml
release:
  name: Create Release
  needs: build
  runs-on: ubuntu-latest
  if: startsWith(github.ref, 'refs/tags/') || github.event_name == 'workflow_dispatch'
  permissions:
    contents: write
```

3. **Tambah Release Notes Generator** (baris 139)
```yaml
generate_release_notes: true
```

## 📋 Checklist
- [x] Tambah `permissions: contents: write` di top level
- [x] Tambah `permissions: contents: write` di release job
- [x] Enable automatic release notes generation
- [x] Maintain backward compatibility

## 🚀 Testing
Untuk test fix ini:

1. **Push tag baru:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Atau trigger manual:**
   - Go to **Actions** → **Cross-Platform Build**
   - Click **Run workflow** → **Run workflow**

3. **Monitor logs** untuk memastikan release berhasil dibuat

## 📚 Reference
- [GitHub Actions Permissions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#permissions)
- [softprops/action-gh-release Documentation](https://github.com/softprops/action-gh-release)
