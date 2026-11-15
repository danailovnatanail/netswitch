# NetSwitch (macOS, Apple Silicon)

Porting della versione Windows per macOS: pannello compatto in stile "flyout" per gestire le
interfacce di rete, ancorato all'icona di NetSwitch nella barra dei menu. Per il momento
supporta solo Mac con processore Apple Silicon (arm64).

> Compilata e provata su un Mac Apple Silicon reale. Vedi "Limiti noti" più sotto.

## Uso
- **Clic sinistro sull'icona** → apre/chiude il pannello (si chiude anche cliccando altrove o
  con Esc).
- **Clic destro sull'icona** → menu rapido: interfacce, configurazioni salvate, avvio
  automatico, esci.
- Rilanciare l'app mentre è già attiva riapre il pannello.

Il pannello segue il tema chiaro/scuro (anche quando cambia con il pannello aperto) e il colore
d'accento di macOS e si posiziona appena sotto l'icona nella barra dei menu (che su macOS è sempre in alto, a differenza della taskbar
di Windows che può stare sopra o sotto).

## Funzioni
Le stesse della versione Windows:
- **Interfacce**: raggruppate in *Connesse*, *Non connesse* e *Disattivate*. Per ognuna: IP,
  modalità DHCP/Statico e interruttore per attivarle/disattivarle (chiede conferma prima di
  disattivare). Clic sulla scheda per i dettagli (gateway, DNS, MAC, velocità): clic su un
  valore = copia negli appunti.
- **Imposta IP**: formato `IP/prefisso` o `IP/subnetmask` (es. `192.168.1.10/24`), più
  indirizzi separati da virgola. Gateway e DNS facoltativi.
- **DHCP**: indirizzo e DNS automatici.
- **Configurazioni salvate**: crea, modifica, duplica, riordina, elimina; applicabili a
  qualsiasi interfaccia dal pannello o dal menu del tasto destro. File:
  `~/Library/Application Support/NetSwitch/configurazioni.xml` (stesso formato XML della
  versione Windows: i file sono intercambiabili tra le due piattaforme).
- **Avvia con il Mac** (menu ⋯): LaunchAgent utente (`~/Library/LaunchAgents`), equivalente
  macOS dell'attività pianificata di Windows.

## Differenza principale rispetto a Windows: privilegi amministrativi
Windows chiede i privilegi di amministratore una sola volta all'avvio (UAC). Su macOS non
esiste un equivalente senza un helper privilegiato firmato con certificato Apple Developer,
quindi:
- `networksetup` (IP statico, DHCP, DNS, attiva/disattiva) viene eseguito prima **senza
  privilegi**: per un utente amministratore macOS lo consente, e non compare nessun prompt.
- Solo se un comando lo richiede (sempre per `ifconfig alias`, cioè gli indirizzi aggiuntivi
  oltre al primo), i comandi rimasti di quell'operazione vengono eseguiti tutti insieme con
  `osascript ... with administrator privileges`: al massimo **una** richiesta di password per
  operazione.
- Le letture (stato delle interfacce, IP, DNS) non richiedono privilegi.

## Compilazione
Serve solo Xcode oppure gli Strumenti da riga di comando di Xcode (per `swiftc`):

    xcode-select --install   # se non già installati
    ./build.sh

Produce `NetSwitch.app` nella cartella corrente, compilato per arm64 (Apple Silicon) e firmato
ad-hoc (senza certificato Apple Developer: al primo avvio macOS potrebbe chiedere conferma in
Preferenze di Sistema → Privacy e Sicurezza → "Apri comunque").

Con `./build.sh -d` viene creato anche `NetSwitch-macOS.dmg` (l'app e un collegamento ad
Applicazioni): è il file pubblicato sul sito.

## Installazione
Apri il DMG e trascina NetSwitch in Applicazioni: l'app è autonoma, non installa nulla e non
ha dipendenze. Poiché non è firmata con un certificato Developer ID né notarizzata da Apple,
al **primo** avvio macOS la blocca: apri Impostazioni di Sistema → Privacy e sicurezza e
scegli "Apri comunque". Dai lanci successivi parte normalmente.

Diagnostica: con `NETSWITCH_DEBUG=1` viene scritto `$TMPDIR/netswitch_debug.log` (stessa
convenzione della versione Windows: `NETSWITCH_FAKE=1`, `NETSWITCH_DEMO=...`,
`NETSWITCH_SNAP=file.png`, `NETSWITCH_THEME=dark|light`, `NETSWITCH_NOHIDE=1`).

## Limiti noti
- **Indirizzi IP multipli per interfaccia**: `networksetup` gestisce un solo indirizzo per
  servizio. Il principale viene impostato con `networksetup -setmanual` (persistente), gli
  aggiuntivi con `ifconfig ... alias`, che **non persistono dopo un riavvio** e richiedono la
  password di amministratore. Passando a DHCP o a un altro IP vengono rimossi.
- **Servizi e interfacce**: su macOS ogni voce è un "servizio di rete"; più servizi possono
  usare la stessa interfaccia fisica (es. `en5`) e macOS attiva solo il primo abilitato
  nell'ordine dei servizi: gli altri vengono mostrati come non connessi.
- **VPN**: lo stato connessa/non connessa viene letto con `scutil --nc`; le VPN non hanno un
  indirizzo configurabile da NetSwitch.
- **Velocità del Wi-Fi**: non mostrata (richiederebbe API private o strumenti deprecati).
- **Avvio automatico**: il LaunchAgent viene letto da macOS al prossimo accesso; punta al
  percorso attuale dell'app, quindi va riattivato se `NetSwitch.app` viene spostata.
- **Notifiche**: al primo esito mostrato a pannello chiuso macOS chiede il permesso.
- **Firma**: l'app è firmata ad-hoc, non notarizzata.

## Esclusione di responsabilità
NetSwitch è fornito "così com'è", senza garanzie di alcun tipo. Modifica la configurazione di
rete del computer: lo usi a tuo rischio. Lo sviluppatore non è responsabile di danni, perdite
di dati o interruzioni di connettività derivanti dal suo utilizzo.
