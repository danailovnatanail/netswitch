# NetSwitch

Pannello compatto in stile Windows 11 per gestire le interfacce di rete, ancorato alla barra
delle applicazioni vicino all'orologio.

## Uso
Esegui `NetSwitch.exe` (richiede privilegi di amministratore: compare il prompt UAC).

- **Clic sinistro sull'icona** → apre/chiude il pannello (si chiude anche cliccando altrove o con Esc).
- **Clic destro sull'icona** → menu rapido: interfacce, configurazioni salvate, avvio automatico, esci.
- Rilanciare l'exe mentre è già attivo riapre il pannello.

Il pannello segue il tema chiaro/scuro e il colore d'accento di Windows e si posiziona sul lato
della barra delle applicazioni (in basso o in alto).

## Funzioni
- **Interfacce**: raggruppate in *Connesse* (pallino verde), *Non connesse* (attive ma senza
  collegamento: pallino ambra e motivo, es. "Cavo scollegato") e *Disattivate* (cerchio vuoto,
  scheda attenuata). Per ognuna: IP, modalità DHCP/Statico e interruttore
  per attivarle/disattivarle (chiede conferma prima di disattivare). Clic sulla scheda per i
  dettagli (gateway, DNS, MAC, velocità): clic su un valore = copia negli appunti.
- **Imposta IP**: formato `IP/prefisso` o `IP/subnetmask` (es. `192.168.1.10/24`), più indirizzi
  separati da virgola. Gateway e DNS facoltativi (se vuoti vengono rimossi). Si può precompilare
  da una configurazione e salvare al volo come nuova configurazione.
- **DHCP**: indirizzo e DNS automatici.
- **Configurazioni salvate**: crea, modifica, duplica, riordina, elimina; applicabili a qualsiasi
  interfaccia dal pannello o dal menu del tasto destro. File: `%APPDATA%\NetSwitch\configurazioni.xml`.
- **Avvia con Windows** (menu ⋯): attività pianificata con privilegi elevati, parte in background
  senza prompt UAC.

## Compilazione
Non serve installare nulla (usa il compilatore C# e WPF inclusi in Windows):

    powershell -ExecutionPolicy Bypass -File build.ps1

Diagnostica: con `NETSWITCH_DEBUG=1` viene scritto `%TEMP%\netswitch_debug.log`.

## Sito web (GitHub Pages)
Il sito di presentazione si trova in `docs/` (pagina unica `index.html`, screenshot in `docs/img/`,
eseguibile scaricabile in `docs/download/NetSwitch.exe`).

Per pubblicarlo: **Settings → Pages → Build and deployment → Source: Deploy from a branch**,
branch `main`, cartella `/docs`. Il link alla repository viene ricavato automaticamente
dall'indirizzo `utente.github.io/repo`; con un dominio personalizzato imposta la costante `REPO`
nello script in fondo a `index.html`.

Dopo una nuova versione aggiorna l'eseguibile del sito:

    powershell -ExecutionPolicy Bypass -File build.ps1 -OutFile docs\download\NetSwitch.exe

Gli screenshot usano interfacce e configurazioni fittizie (nessun dato reale del PC). Per
rigenerarli, con una build di prova (`-NoElevation`):

    $env:NETSWITCH_DEBUG='1'; $env:NETSWITCH_FAKE='1'; $env:NETSWITCH_NOHIDE='1'
    $env:NETSWITCH_THEME='dark'          # oppure light
    $env:NETSWITCH_DEMO='expand'         # vuoto, expand, editor, configs
    $env:NETSWITCH_SNAP='docs\img\expand-dark.png'
    .\NetSwitch.exe

## Esclusione di responsabilità
NetSwitch è fornito "così com'è", senza garanzie di alcun tipo. Modifica la configurazione di rete
del computer: lo usi a tuo rischio. Lo sviluppatore non è responsabile di danni, perdite di dati o
interruzioni di connettività derivanti dal suo utilizzo.
