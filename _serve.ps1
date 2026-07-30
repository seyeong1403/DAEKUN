param([int]$Port=8801, [string]$Root='C:\Users\PC\Desktop\daekunms')
Add-Type -AssemblyName System.Web
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root at http://localhost:$Port/"
$mime = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'
  '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8'
  '.json'='application/json'; '.svg'='image/svg+xml'; '.png'='image/png'
  '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.gif'='image/gif'; '.webp'='image/webp'
  '.mp4'='video/mp4'; '.ico'='image/x-icon'; '.woff'='font/woff'; '.woff2'='font/woff2'
  '.ttf'='font/ttf'; '.eot'='application/vnd.ms-fontobject'; '.otf'='font/otf'
  '.pdf'='application/pdf'
}
while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $path = [System.Web.HttpUtility]::UrlDecode($ctx.Request.Url.AbsolutePath)
    if ($path.EndsWith('/')) { $path += 'index.html' }
    $file = Join-Path $Root ($path.TrimStart('/') -replace '/','\')
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      $ct = $mime[$ext]; if (-not $ct) { $ct = 'application/octet-stream' }
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ctx.Response.ContentType = $ct
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
      $ctx.Response.OutputStream.Write($msg,0,$msg.Length)
    }
    $ctx.Response.OutputStream.Close()
  } catch {}
}
