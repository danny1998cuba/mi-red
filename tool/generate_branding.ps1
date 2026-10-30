param(
  [string]$FontPath = "$env:LOCALAPPDATA/Pub/Cache/hosted/pub.dev/forui-0.27.7/assets/fonts/inter/Inter.ttf"
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $workspace 'assets/branding'
$resourceRoot = Join-Path $workspace 'android/app/src/main/res'
if (-not (Test-Path -LiteralPath $FontPath)) { throw 'Inter local no disponible. Ejecuta flutter pub get o indica -FontPath.' }
function Measure-Radius([string]$path) {
  $image = [Drawing.Bitmap]::new($path)
  $radius = 0.0
  for ($y=0; $y -lt $image.Height; $y++) {
    for ($x=0; $x -lt $image.Width; $x++) {
      if ($image.GetPixel($x,$y).A -gt 0) {
        $dx=$x-($image.Width-1)/2.0; $dy=$y-($image.Height-1)/2.0
        $radius=[Math]::Max($radius,[Math]::Sqrt($dx*$dx+$dy*$dy))
      }
    }
  }
  $image.Dispose()
  return $radius
}

$sourceNames = @('mi_red_logo_master.png','mi_red_adaptive_foreground.png','mi_red_adaptive_monochrome.png','mi_red_legacy_icon.png','mi_red_splash_mark.png','mi_red_assets_preview.png')
$inputs = @{}
foreach ($name in $sourceNames) {
  $path = Join-Path $sourceRoot $name
  $image = [Drawing.Bitmap]::new($path)
  $inputs[$name] = @{width=$image.Width; height=$image.Height; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
  if ($name -ne 'mi_red_assets_preview.png' -and $image.Width -ne $image.Height) { throw 'Los activos de producción deben ser cuadrados.' }
  if ($name -notin @('mi_red_legacy_icon.png','mi_red_assets_preview.png') -and $image.GetPixel(0,0).A -ne 0) { throw 'Falta transparencia en el activo.' }
  $image.Dispose()
}
$foreground = Join-Path $sourceRoot 'mi_red_adaptive_foreground.png'
$radius = Measure-Radius $foreground
# Keep every visible pixel inside a 65 dp circle on the 108 dp adaptive canvas.
$safeScale = [Math]::Min(1.0, (1024.0 * 32.5 / 108.0) / $radius)
$fonts = [Drawing.Text.PrivateFontCollection]::new()
$fonts.AddFontFile([IO.Path]::GetFullPath($FontPath))
$fontFamily = $fonts.Families[0]

function New-Canvas([int]$width, [int]$height) {
  $bitmap = [Drawing.Bitmap]::new($width,$height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear([Drawing.Color]::Transparent)
  $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
  return @($bitmap,$graphics)
}
function Resize-Branding([string]$source, [string]$target, [int]$size, [double]$scale = 1.0) {
  $canvas = New-Canvas $size $size
  $image = [Drawing.Bitmap]::new($source)
  $drawSize = [int][Math]::Round($size * $scale)
  $offset = [int][Math]::Floor(($size - $drawSize) / 2)
  $attributes = [Drawing.Imaging.ImageAttributes]::new()
  $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
  $canvas[1].DrawImage($image,[Drawing.Rectangle]::new($offset,$offset,$drawSize,$drawSize),0,0,$image.Width,$image.Height,[Drawing.GraphicsUnit]::Pixel,$attributes)
  $canvas[0].Save($target,[Drawing.Imaging.ImageFormat]::Png)
  $attributes.Dispose(); $image.Dispose(); $canvas[1].Dispose(); $canvas[0].Dispose()
}
function Write-BrandingText([string]$target, [double]$density, [string]$color) {
  $canvas = New-Canvas ([int](200*$density)) ([int](80*$density))
  $canvas[1].TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
  $titleFont = [Drawing.Font]::new($fontFamily,[single](24*$density),[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
  $subtitleFont = [Drawing.Font]::new($fontFamily,[single](12*$density),[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
  $format = [Drawing.StringFormat]::new()
  $format.Alignment = [Drawing.StringAlignment]::Center
  $canvas[1].DrawString('Mi Red',$titleFont,$brush,[Drawing.RectangleF]::new(0,0,[single](200*$density),[single](36*$density)),$format)
  $canvas[1].DrawString('Gestión de clientes y cobros',$subtitleFont,$brush,[Drawing.RectangleF]::new(0,[single](40*$density),[single](200*$density),[single](30*$density)),$format)
  $canvas[0].Save($target,[Drawing.Imaging.ImageFormat]::Png)
  $format.Dispose(); $titleFont.Dispose(); $subtitleFont.Dispose(); $brush.Dispose(); $canvas[1].Dispose(); $canvas[0].Dispose()
}
function Write-Resource([string]$relative, [string]$text) {
  $path = Join-Path $resourceRoot $relative
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($path)) | Out-Null
  [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))
}
foreach ($density in @(@('mdpi',1.0),@('hdpi',1.5),@('xhdpi',2.0),@('xxhdpi',3.0),@('xxxhdpi',4.0))) {
  $name = $density[0]; $factor = [double]$density[1]
  foreach ($folder in @("mipmap-$name","drawable-$name","drawable-night-$name")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $resourceRoot $folder) | Out-Null
  }
  Resize-Branding (Join-Path $sourceRoot 'mi_red_legacy_icon.png') (Join-Path $resourceRoot "mipmap-$name/ic_launcher.png") ([int](48*$factor))
  Resize-Branding $foreground (Join-Path $resourceRoot "mipmap-$name/ic_launcher_foreground.png") ([int](108*$factor)) $safeScale
  Resize-Branding (Join-Path $sourceRoot 'mi_red_adaptive_monochrome.png') (Join-Path $resourceRoot "mipmap-$name/ic_launcher_monochrome.png") ([int](108*$factor)) $safeScale
  Resize-Branding (Join-Path $sourceRoot 'mi_red_splash_mark.png') (Join-Path $resourceRoot "drawable-$name/mi_red_splash_mark.png") ([int](288*$factor))
  Write-BrandingText (Join-Path $resourceRoot "drawable-$name/mi_red_splash_branding.png") $factor '#0B1220'
  Write-BrandingText (Join-Path $resourceRoot "drawable-night-$name/mi_red_splash_branding.png") $factor '#F8FAFC'
}
Write-Resource 'mipmap-anydpi-v26/ic_launcher.xml' @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/mi_red_launcher_background" />
  <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@
Write-Resource 'mipmap-anydpi-v33/ic_launcher.xml' @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/mi_red_launcher_background" />
  <foreground android:drawable="@mipmap/ic_launcher_foreground" />
  <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
'@
Write-Resource 'values/branding_colors.xml' @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <color name="mi_red_launcher_background">#0B1220</color>
  <color name="mi_red_splash_background">#F8FAFC</color>
</resources>
'@
Write-Resource 'values-night/branding_colors.xml' @'
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="mi_red_splash_background">#0B1220</color></resources>
'@
$launchBackground = @'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:drawable="@color/mi_red_splash_background" />
  <item><bitmap android:gravity="center" android:src="@drawable/mi_red_splash_mark" /></item>
  <item android:bottom="48dp"><bitmap android:gravity="bottom|center_horizontal" android:src="@drawable/mi_red_splash_branding" /></item>
</layer-list>
'@
Write-Resource 'drawable/launch_background.xml' $launchBackground
Write-Resource 'drawable-v21/launch_background.xml' $launchBackground
foreach ($night in @($false,$true)) {
  $base = if ($night) { 'Theme.Black.NoTitleBar' } else { 'Theme.Light.NoTitleBar' }
  $lightBars = if ($night) { 'false' } else { 'true' }
  $qualifier = if ($night) { 'values-night' } else { 'values' }
  Write-Resource "$qualifier/styles.xml" @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <style name="LaunchTheme" parent="@android:style/$base">
    <item name="android:windowBackground">@drawable/launch_background</item>
    <item name="android:windowLightStatusBar">$lightBars</item>
  </style>
  <style name="NormalTheme" parent="@android:style/$base">
    <item name="android:windowBackground">@color/mi_red_splash_background</item>
  </style>
</resources>
"@
  Write-Resource "$qualifier-v31/styles.xml" @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <style name="LaunchTheme" parent="@android:style/$base">
    <item name="android:windowSplashScreenBackground">@color/mi_red_splash_background</item>
    <item name="android:windowSplashScreenAnimatedIcon">@drawable/mi_red_splash_mark</item>
    <item name="android:windowSplashScreenBrandingImage">@drawable/mi_red_splash_branding</item>
    <item name="android:windowSplashScreenAnimationDuration">0</item>
    <item name="android:windowLightStatusBar">$lightBars</item>
  </style>
  <style name="NormalTheme" parent="@android:style/$base">
    <item name="android:windowBackground">@color/mi_red_splash_background</item>
  </style>
</resources>
"@
}
$fonts.Dispose()
foreach ($name in $sourceNames) {
  if ((Get-FileHash -LiteralPath (Join-Path $sourceRoot $name) -Algorithm SHA256).Hash -ne $inputs[$name].sha256) { throw 'Se modificó un activo fuente.' }
}
[pscustomobject]@{inputs=$inputs; adaptiveScale=$safeScale; fontSha256=(Get-FileHash -LiteralPath $FontPath -Algorithm SHA256).Hash} | ConvertTo-Json -Depth 5
