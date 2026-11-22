# Mi Red — Guía de exportación del APK Android

**Proyecto:** Mi Red · **Desarrollado por:** [CoreX4Dev](https://corex4dev.com)  
**Entorno:** Windows, PowerShell, VS Code, Flutter y Android SDK (sin Android Studio)  
**Objetivo:** generar **un único APK Release firmado**, verificable y listo para distribuir fuera de Google Play.

> Este es el procedimiento de firma **manual** usado para Mi Red. La compilación Release del proyecto produce un APK sin firma de distribución: hay que alinearlo y firmarlo antes de compartirlo. **No hace falta generar variantes por arquitectura.**

## 1. Preparación (una sola vez)

Necesitas Flutter, el Android SDK con Build Tools y el **keystore de distribución existente** de Mi Red. Usa siempre el mismo keystore y alias para que las nuevas versiones puedan actualizar las anteriores sin borrar datos.

Rutas utilizadas en este ejemplo:

| Elemento | Ruta |
|---|---|
| Repositorio | `C:\02 Work\mi-red` |
| SDK Android | `%LOCALAPPDATA%\Android\Sdk` |
| Keystore | `%USERPROFILE%\MiRed-Keys\mi-red-release.jks` |
| Alias | `mi-red-release` |
| APK entregable | `C:\02 Work\mi-red\dist\` |

> **Nunca** subas el `.jks`, sus contraseñas ni archivos de respaldo reales al repositorio público. Conserva una copia de la clave en un lugar seguro, separada del equipo de desarrollo. No crees una clave nueva para una actualización.

Comprueba el entorno:

```powershell
cd "C:\02 Work\mi-red"
flutter doctor
Test-Path "$env:USERPROFILE\MiRed-Keys\mi-red-release.jks"
```

El último comando debe devolver `True`.

## 2. Actualizar la versión

En `pubspec.yaml`, modifica la propiedad `version` según la entrega:

```yaml
version: 1.0.1+2
```

- `1.0.1` es la versión visible para el usuario (`versionName`).
- `2` es el número interno de compilación (`versionCode`). **Debe ser mayor que el de la versión ya instalada** para actualizarla.

Para la primera versión, el ejemplo equivalente fue `1.0.0+1`. No cambies el identificador Android `com.mired.offline`.

## 3. Validar y compilar

Desde la raíz del proyecto:

```powershell
cd "C:\02 Work\mi-red"
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

El APK de salida será:

```text
build\app\outputs\flutter-apk\app-release.apk
```

**No compartas todavía ese archivo:** en la configuración manual de Mi Red, aún requiere la firma de distribución.

## 4. Preparar las herramientas de firma

En la misma terminal PowerShell:

```powershell
$ErrorActionPreference = "Stop"

$project = "C:\02 Work\mi-red"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$key = "$env:USERPROFILE\MiRed-Keys\mi-red-release.jks"

$buildTools = Get-ChildItem "$sdk\build-tools" -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
  Sort-Object { [version]$_.Name } -Descending |
  Select-Object -First 1

if (-not $buildTools) { throw "No se encontraron Android SDK Build Tools." }

$zipalign = Join-Path $buildTools.FullName "zipalign.exe"
$apksigner = Join-Path $buildTools.FullName "apksigner.bat"

$source = Join-Path $project "build\app\outputs\flutter-apk\app-release.apk"
$aligned = Join-Path $project "build\app\outputs\flutter-apk\app-aligned.apk"
$dist = Join-Path $project "dist"
$final = Join-Path $dist "MiRed-1.0.1-release.apk"

New-Item -ItemType Directory -Force -Path $dist | Out-Null

foreach ($file in @($zipalign, $apksigner, $source, $key)) {
  if (-not (Test-Path $file)) { throw "Archivo no encontrado: $file" }
}
```

**Importante:** cambia el nombre de `$final` para que coincida con la versión definida en el paso 2 (por ejemplo, `MiRed-1.0.0-release.apk` para la versión inicial).

## 5. Alinear el APK

```powershell
& $zipalign -P 16 -f -v 4 $source $aligned
if ($LASTEXITCODE -ne 0) { throw "Falló zipalign." }
```

La alineación se ejecuta **antes** de firmar. No modifiques el APK después de firmarlo.

## 6. Firmar con la clave existente

```powershell
& $apksigner sign `
  --ks $key `
  --ks-key-alias "mi-red-release" `
  --out $final `
  $aligned

if ($LASTEXITCODE -ne 0) { throw "Falló la firma del APK." }
```

Introduce la contraseña del keystore cuando se te solicite. **No la pongas en el comando ni en archivos del repositorio.**

## 7. Verificar el APK final

```powershell
& $apksigner verify --verbose --print-certs $final
if ($LASTEXITCODE -ne 0) { throw "El APK firmado no se verificó." }

& $zipalign -c -P 16 -v 4 $final
if ($LASTEXITCODE -ne 0) { throw "El APK no superó la comprobación de alineación." }

Get-Item $final | Select-Object FullName, Length
Get-FileHash $final -Algorithm SHA256
```

La verificación de firma debe completarse sin errores y mostrar firmas válidas (incluida v2). Guarda la huella **SHA-256** junto al archivo de distribución para comprobar que la copia descargada es idéntica.

## 8. Probar y distribuir

1. **Prueba el archivo firmado exacto** en un Android real, no el APK de `build/` sin firmar.
2. Comprueba que abre sin Flutter/ADB y que funciona sin conexión.
3. Si es una **actualización**, instala sobre la versión Release anterior sin desinstalar. Debes haber conservado el mismo `applicationId` y la misma firma, además de incrementar el `versionCode`.
4. Confirma que los clientes, cobros y ajustes existentes continúan presentes.
5. Antes de actualizaciones importantes, crea y conserva una **copia de seguridad cifrada** fuera del teléfono, junto con su contraseña.
6. Comparte **solo** el archivo final de `dist/` por GitHub Releases o el medio elegido.

Si tuvieras el teléfono conectado por ADB, la comprobación opcional sería:

```powershell
adb install -r "C:\02 Work\mi-red\dist\MiRed-1.0.1-release.apk"
```

> **Precaución:** Android no permite reemplazar directamente una instalación *Debug* con otra *Release* firmada con un certificado diferente. Antes de desinstalar una versión Debug, exporta y comprueba un respaldo para no perder SQLite.

## 9. Checklist previo a cada publicación

- [ ] Versión y `versionCode` actualizados en `pubspec.yaml`.
- [ ] `flutter analyze` y `flutter test` aprobados.
- [ ] `flutter build apk --release` completado.
- [ ] `zipalign` ejecutado **antes** de la firma.
- [ ] Firmado con el keystore **original** de CoreX4Dev.
- [ ] `apksigner verify` y `zipalign -c` correctos.
- [ ] APK final probado en Android.
- [ ] Una actualización conserva los datos existentes.
- [ ] Huella SHA-256 guardada y archivo correcto subido a distribución.
- [ ] Keystore, contraseña y respaldos permanecen fuera del repositorio.

## Referencias oficiales

- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Android: Build your app from the command line](https://developer.android.com/build/building-cmdline)
- [Android: zipalign](https://developer.android.com/tools/zipalign)
- [Android: apksigner](https://developer.android.com/tools/apksigner)

---

**Mi Red — CoreX4Dev**  
https://corex4dev.com
