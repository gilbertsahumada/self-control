# BlockSites

Herramienta minimalista de terminal para bloquear sitios web en macOS por un período de tiempo definido. Una vez activado, **no se puede desactivar** hasta que expire el tiempo.

## Instalación

```bash
# Compilar
swift build -c release

# Instalar binarios
sudo cp .build/release/BlockSites /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer

# Dar permisos de ejecución
sudo chmod +x /usr/local/bin/blocksites
sudo chmod +x /usr/local/bin/blocksites-enforcer
```

## Uso

### Bloquear sitios

```bash
# Por horas
sudo blocksites --hours 2 --sites facebook.com,twitter.com,instagram.com

# Por minutos (útil para pruebas)
sudo blocksites --minutes 1 --sites facebook.com,twitter.com

# Combinando horas y minutos
sudo blocksites --hours 1 --minutes 30 --sites facebook.com,twitter.com
```

Esto bloqueará los sitios por el tiempo especificado. **No hay forma de desbloquearlos antes**.

### Ver estado

```bash
blocksites --status
```

Muestra qué sitios están bloqueados y cuánto tiempo queda.

## Cómo funciona

1. **Bloqueo doble**: Modifica `/etc/hosts` Y configura reglas de firewall (`pf`)
2. **Nivel de DNS**: Redirige los sitios a `127.0.0.1`
3. **Nivel de red**: Bloquea las IPs de los sitios en el firewall (evita DoH/DNS over HTTPS)
4. **Daemon vigilante**: Verifica cada minuto que los bloqueos sigan activos
5. **Auto-restauración**: Si intentas modificar `/etc/hosts` o el firewall, se restaura automáticamente
6. **Auto-limpieza**: Cuando expire el tiempo, se limpia todo automáticamente

## ⚠️ Advertencia

Esta herramienta es **a propósito difícil de desactivar**. La única forma de detenerla antes de tiempo es:
- Reiniciar en Recovery Mode y modificar archivos del sistema
- O simplemente esperar a que expire el tiempo

Úsala con responsabilidad.
