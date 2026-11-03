# Changelog - Gang Retaliation

## [Unreleased]

### English

#### Added
- **They Will Remember integration (optional).** When a TWR vengeance squad of a gang with a living
  Nemesis fights V, that Nemesis may join and lead it (same chance as gig reinforcements). TWR's
  grudge (gang hostile, recent kills) raises the ambush chance, up to x2.
  - **Vengeance warning:** when TWR picks a gang to strike back, that gang's Boss or Lieutenant
    Nemesis who knows V texts V first (new messages in the "Unknown number" thread).
  - **Money doesn't buy a Nemesis:** if V pays TWR's redemption to a gang, TWR forgets, but its
    Boss or Lieutenant Nemesis turns it down by text. Their ambushes drop to half for 3 game days.
- **Drug Dealer integration (optional).** Gang Retaliation's ambushes, raids and skirmishes wait while a
  Drug Dealer job has enemies alive. A Nemesis may show up with the gang raiding your business or
  defending its turf. Your dealer rank raises the ambush chance (up to x1.48). Your Drug Dealer
  soldiers never become Nemeses, and an enemy that Drug Dealer removes while fleeing no longer counts
  as escaped.
  - **Turf:** in a zone V contests in Drug Dealer, its gangs ambush more (x1.25); in a zone V
    controls, they want it back (x1.5). The NEMESIS menu shows it: "TAKEN BY V" / "CONTESTED BY V"
    on each neighborhood, a line in the district detail, and "Territory lost to V: ..." on each gang.
  - **Terror:** Drug Dealer's terror makes gangers flee sooner (up to +15% on the flee health; the
    flee mark on the health bar moves with it).
- Both work only if the other mod is installed; without it nothing changes.

#### Changed
- **Tougher Nemeses.** They had the same health as a regular ganger. Now health scales with rank:
  Soldier x1.5, Lieutenant x2.5, Boss x4 (escorts unchanged). New Mod Settings category "Nemesis
  toughness" to tune each rank, plus an optional "Level based on V" (off by default: district level,
  as before) with extra levels per rank.
- **Quieter Nemesis notifications.** Updates (escapes, rumors, promotions, deaths...) now go to
  the side log, like looted items, with no sound and no screen buzz. The old big warning in the
  middle of the screen is still available: Mod Settings > General > "Center-screen notifications".
- **No notifications during cutscenes.** They wait until quest scenes (e.g. Johnny's memories),
  braindances and menus are over, then show one by one.

### Español

#### Agregado
- **Integración con They Will Remember (opcional).** Cuando un escuadrón de venganza de TWR de una
  banda con Némesis vivo pelea con V, ese Némesis puede sumarse y encabezarlo (misma probabilidad
  que los refuerzos de gigs). El rencor de TWR (banda hostil, muertes recientes) sube la
  probabilidad de emboscada, hasta x2.
  - **Aviso de venganza:** cuando TWR elige una banda para vengarse, su Jefe o Teniente Némesis que
    conoce a V le escribe antes (mensajes nuevos en el hilo "Número desconocido").
  - **La plata no compra a un Némesis:** si V le paga el perdón de TWR a una banda, TWR olvida, pero
    su Jefe o Teniente Némesis lo rechaza por SMS. Sus emboscadas bajan a la mitad durante 3 días de
    juego.
- **Integración con Drug Dealer (opcional).** Las emboscadas, redadas y escaramuzas de Gang
  Retaliation esperan mientras una misión de Drug Dealer tenga enemigos vivos. Un Némesis puede
  aparecer con la banda que ataca tu negocio o defiende su territorio. Tu rango de traficante sube la
  probabilidad de emboscada (hasta x1.48). Tus soldados de Drug Dealer nunca se vuelven Némesis, y un
  enemigo que Drug Dealer borra mientras huye ya no cuenta como escapado.
  - **Territorio:** en una zona que V disputa en Drug Dealer, sus bandas emboscan más (x1.25); en una
    zona que V controla, la quieren recuperar (x1.5). El menú NÉMESIS lo muestra: "EN MANOS DE V" /
    "DISPUTADO CON V" en cada barrio, una línea en el detalle del distrito y "Territorio perdido ante V: ..." en
    cada banda.
  - **Terror:** el terror de Drug Dealer hace que los pandilleros huyan antes (hasta +15% en la vida
    para huir; la marca de huida de la barra de vida se mueve con él).
- Las dos solo actúan si el otro mod está instalado; sin él no cambia nada.

#### Cambiado
- **Némesis más duros.** Tenían la misma vida que un pandillero común. Ahora la vida sube con el
  rango: Soldado x1.5, Teniente x2.5, Jefe x4 (la escolta no cambia). Categoría nueva en Mod Settings,
  "Dureza de los Némesis", para ajustar cada rango, más un "Nivel según V" opcional (apagado por
  defecto: nivel del distrito, como antes) con niveles extra por rango.
- **Avisos de Némesis más discretos.** Las novedades (escapes, rumores, ascensos, muertes...) ahora
  van al registro lateral, como los objetos saqueados, sin sonido ni vibración de pantalla. El aviso
  grande en el centro sigue disponible: Mod Settings > General > "Avisos en el centro de la pantalla".
- **Sin avisos durante las escenas.** Esperan a que terminen las escenas de misión (p. ej. los
  recuerdos de Johnny), las danzas cerebrales y los menús, y después salen de a uno.

## [1.3.2] - 2026-11-02

### English

#### Fixed
- **Jackie (and other allies) could become a Nemesis.** Jackie is a Valentino, so hitting him by
  accident in a fight made him a candidate. Companions and NPCs friendly to V are now ignored.

#### Changed
- **Vehicle ambushes start on the street.** The car now spawns next to a car that is already in
  traffic or parked nearby, facing the same way as the lane and pointing towards V, with a walking
  path to V. Before, it used any walkable point, which could be a sidewalk or a plaza, so some
  ambushes ended up on foot. If there is no usable car nearby, it falls back to the old method.
  Idea taken from They Will Remember.
- **Ambush cars drive faster** (they used to arrive after V had already left).
- **NCPD raids no longer pop up in front of V.** They now spawn behind or to the sides, outside a
  70° cone in front of V and with no line of sight. Every cop and ganger is checked, not just the
  center of each group (some used to appear in sight, inside walls or on another floor).
- **NCPD and gangers just staring at each other in raids.** Hostility between the two sides was
  set only once, when each NPC spawned; if its AI was not ready yet, it stayed passive. Now, every
  3 seconds, anyone not fighting is pointed at the nearest living enemy (like the passive Nemesis
  fix for ambushes).

### Español

#### Arreglado
- **Jackie (y otros aliados) podían volverse Némesis.** Jackie es Valentino, así que pegarle sin
  querer en una pelea lo volvía candidato. Ahora se ignoran los acompañantes y los NPC amistosos
  con V.

#### Cambiado
- **Las emboscadas en vehículo arrancan en la calle.** El auto ahora aparece junto a un auto que ya
  está en el tráfico o estacionado cerca, mirando como el carril y hacia V, con camino a pie hasta V.
  Antes usaba cualquier punto caminable, que podía ser una vereda o una plaza, y algunas emboscadas
  terminaban a pie. Si no hay un auto útil cerca, usa el método anterior. Idea tomada de They Will
  Remember.
- **Los autos de emboscada manejan más rápido** (antes llegaban cuando V ya se había ido).
- **Las redadas de la NCPD ya no aparecen delante de V.** Ahora aparecen detrás o a los costados,
  fuera de un cono de 70° delante de V y sin línea de vista. Se revisa a cada policía y pandillero,
  no solo el centro de cada grupo (algunos aparecían a la vista, dentro de paredes o en otro piso).
- **Policías y pandilleros que se quedaban mirándose en las redadas.** La hostilidad entre los dos
  bandos se ponía una sola vez, al aparecer cada NPC; si su IA no estaba lista, quedaba pasivo.
  Ahora, cada 3 segundos, a quien no esté peleando se le marca el enemigo vivo más cercano (como el
  arreglo de Némesis pasivos en las emboscadas).

## [1.3.1] - 2026-11-01

### English

#### Fixed
- **"I'm back" SMS missing from the phone.** When a Nemesis returned from the ripperdoc, the
  message only showed as a popup and never reached the inbox. It now goes to the "Unknown number"
  thread like the ambush threats.
- **Crashes in big fights and when combat ends.** The game delivers hits, deaths and combat changes
  on several threads at once. The mod updated its fight lists right there, so two threads could change them together and crash the game (reported with Wraiths in the Badlands). Now those events only queue a call, and the mod handles them on the main
  thread. Fighters are also kept by ID instead of by reference.

### Español

#### Arreglado
- **SMS de "volví" que no estaba en el teléfono.** Cuando un Némesis volvía del matasanos, el
  mensaje solo salía como aviso y nunca llegaba a la bandeja. Ahora va al hilo "Número
  desconocido", como las amenazas de emboscada.
- **Crashes en peleas grandes y al terminar el combate.** El juego entrega los golpes, las muertes y
  los cambios de combate en varios hilos a la vez (un escopetazo a un grupo, por ejemplo). El mod
  actualizaba sus listas de la pelea ahí mismo, así que dos hilos podían tocarlas juntos y el juego
  crasheaba (reportado con Wraiths en las Badlands). Ahora esos eventos solo agendan una llamada y
  el mod los procesa en el hilo principal. Los peleadores además se guardan por ID y no por
  referencia.

## [1.3.0] - 2026-10-31

### English

#### New
- **Bigger enemy health bar.** The bar over the enemy you look at can be scaled up (x1.5 by default,
  x1 to x2 in Mod Settings).
- **Flee line.** A yellow line on the enemy's health bar marks the health at which they'll run away
  if left last standing. It only shows when that ganger really can flee: not in scenes, vehicles or
  on bosses, so it never promises an escape that won't happen.
- **THREATS panel.** In combat, a box on the left lists the enemies targeting you. Each row shows
  the gang color, the name (the Nemesis name if it is one, otherwise the gang), the distance and a
  small health bar with its own flee line. Below the threshold, the bar turns amber.
  - The enemy you're looking at comes first, then Nemeses, then by distance. The rest show as
    "+N more".
  - It hides 3 s after combat and while the weapon wheel is open.
  - Same size at any resolution.
- **HUD options in Mod Settings** (new HUD category): enemy bar size, flee line on/off, threats
  panel on/off, panel X/Y position, size, background opacity and number of rows. Everything applies
  live, no restart needed.

#### Changed
- **Tracking a job no longer disables fleeing.** Before, with a main or side job tracked, nobody
  fled anywhere on the map, and almost everyone always tracks a job. Now fleeing is only blocked
  when V is within 150 m of that job's objective.
- **Gangers who flee and survive become Nemeses.** A ganger who fled and turned back to fight (so
  they don't leave the area) now becomes a Nemesis if still alive when combat ends, even with more
  health than the "wounded escape" threshold.
- **SMS-announced ambushes wait longer.** If they can't start (V in combat, indoors, in a vehicle),
  they retry for 30 minutes instead of 10 before being cancelled.

#### Fixed
- **Ambushes blocked by They Will Remember corpses.** The TWR squad check also counted dead members,
  which TWR doesn't remove while you're nearby. Now only living ones count.
- **Boss health bar stuck on screen.** When the Nemesis died, the ambush ended or you moved away
  (even by fast travel), the boss bar could stay at the top of the screen. It's now checked every
  second and removed if the Nemesis no longer exists, is dead or downed, or is more than 100 m away.
- **Nemeses spawning passive.** If the NPC wasn't ready when it spawned, it never entered combat
  and just stood there. Now, during the ambush, those still out of combat near V are provoked again
  every 3 s (up to 6 times).

### Español

#### Nuevo
- **Barra de vida del enemigo más grande.** La barra sobre el enemigo que mirás se puede agrandar
  (x1.5 por defecto, de x1 a x2 en Mod Settings).
- **Línea de huida.** Una línea amarilla en la barra del enemigo marca con cuánta vida va a huir si
  queda último en pie. Solo aparece cuando ese pandillero de verdad puede huir: no en escenas, en
  vehículos ni con jefes, así que nunca promete una huida que no va a pasar.
- **Panel AMENAZAS.** En combate, un recuadro a la izquierda lista a los enemigos que te tienen como
  objetivo. Cada fila lleva el color de la banda, el nombre (el del Némesis si lo es, si no el de la
  banda), la distancia y una barra de vida pequeña con su propia línea de huida. Por debajo del
  umbral, la barra se pone ámbar.
  - Primero el enemigo que mirás, después los Némesis y después por distancia. Los que no entran
    aparecen como "+N más".
  - Se oculta 3 s después del combate y mientras está abierta la rueda de armas.
  - Se ve del mismo tamaño en cualquier resolución.
- **Opciones de HUD en Mod Settings** (nueva categoría HUD): tamaño de la barra enemiga, línea de
  huida sí/no, panel de amenazas sí/no, posición X/Y del panel, tamaño, opacidad del fondo y
  cantidad de filas. Todo se aplica en vivo, sin reiniciar.

#### Cambiado
- **Seguir una misión ya no apaga las huidas.** Antes, con una misión principal o secundaria
  seguida, nadie huía en ningún lugar del mapa, y casi todos siguen siempre alguna misión. Ahora
  solo se bloquea la huida si V está a menos de 150 m del objetivo de esa misión.
- **Los que huyen y sobreviven se vuelven Némesis.** Un pandillero que huyó y vuelve a pelear para
  no salir de la zona ahora se convierte en Némesis si sigue vivo al terminar el combate, aunque
  tenga más vida que el umbral de "huida herida".
- **La emboscada anunciada por SMS espera más.** Si no puede salir (V en combate, bajo techo, en
  vehículo), reintenta durante 30 minutos en vez de 10 antes de cancelarse.

#### Arreglado
- **Emboscadas bloqueadas por cadáveres de They Will Remember.** El bloqueo por escuadrón de TWR
  contaba también a los miembros muertos, que TWR no borra mientras estés cerca. Ahora solo cuentan
  los vivos.
- **Barra de jefe trabada en pantalla.** Cuando el Némesis moría, la emboscada terminaba o te
  alejabas (incluso teletransportándote), la barra de jefe podía quedarse arriba de la pantalla.
  Ahora se revisa cada segundo y se quita si el Némesis ya no existe, está muerto o derribado, o
  quedó a más de 100 m.
- **Némesis que aparecían pasivos.** Si el NPC todavía no estaba listo cuando aparecía, no entraba
  en combate y se quedaba quieto. Ahora, mientras dura la emboscada, los que siguen fuera de combate
  cerca de V se vuelven a provocar cada 3 s (hasta 6 veces).

## [1.2.2] - 2026-10-29

### Arreglado
- **Crash al terminar un combate** (`GRDetection.OnPlayerCombatEnded`, reportado con They Will
  Remember, Dark Future y EDO). El texto de depuración se armaba siempre, aunque el log de
  depuración estuviera apagado, y la lista de candidatos se recorría mientras otro evento podía
  modificarla.
- **Némesis falsos con mods que borran NPCs.** Un pandillero que desaparece al acabar el combate
  (por ejemplo, un escuadrón de They Will Remember que el mod borra) ya no se asciende como
  "escapó herido".
- **"No se pudo escribir data/gang_retaliation.json".** Vortex no instalaba la carpeta `data`
  vacía y el mod no podía guardar a sus Némesis. Ahora viene con un archivo `.keep` adentro.

### Cambiado
- **Rendimiento.** La capa CET ya no consulta al juego en cada frame: todo va en un tick de 1 s.
  El menú NÉMESIS se reconstruye solo cuando cambian los datos, y no cada 2 s aunque esté
  cerrado. Medido con 44 Némesis: los picos bajan de 11 ms a 4 ms y casi no hay gasto en reposo.
- **Compatibilidad con They Will Remember.** Mientras haya un escuadrón de venganza de TWR en el
  mapa, no salen emboscadas, redadas de la NCPD ni escaramuzas de Gang Retaliation, para no
  sumar dos ataques a la vez. Sin TWR instalado no cambia nada.

## [1.2.1] - 2026-10-29

### Nuevo
- **Emboscadas en vehículo.** El Némesis y su escolta pueden llegar en coche, aparcar y bajarse.
  Si no hay sitio detrás de V, llegan a pie.
- **Casas de V.** Cerca de una casa de V no hay emboscadas (probabilidad 0 a menos de 60 m,
  normal a más de 300 m). El departamento H10 viene de fábrica; el resto se aprende al dormir
  2 noches en él.

### Arreglado
- **Emboscadas dentro del departamento o en pasillos.** Ahora solo aparecen a cielo abierto: si V
  está bajo techo, la emboscada anunciada espera a que salga. Tampoco salen en escenas donde V no
  puede sacar el arma.
- **Misiones que no se podían terminar porque el último enemigo huía.** No hay huidas en las
  misiones de historia que V tiene seguidas, y los NPCs del mundo ya no salen de la zona al huir.
- **Emboscadas atascadas.** Se cierran solas a los 40 s.
- Durante una emboscada, defenderse no cuenta como delito.

## [1.2] - 2026-10-28

### Nuevo
- **Redadas de la NCPD cerca de V.** Un Némesis de la zona y su escolta se enfrentan a una patrulla
  de 3 a 5 policías (más cuanto más alto el rango), a unos 30 m de V.
  - Probabilidad por minuto configurable en Mod Settings ("Redadas de la NCPD cerca de V", 10%),
    como mucho una cada 15 minutos.
  - V puede mirar, ayudar a la policía o ayudar a la banda. La banda nace hostil con V (así
    dispararle no es delito) y la policía, amistosa.
  - Durante la redada nadie huye: el Némesis pelea hasta el final.
  - Si el Némesis sobrevive, gana 2 de renombre y corre el rumor de que escapó.
- **Recompensa de la NCPD.** Si la banda cae entera con ayuda de V, la NCPD paga según el rango
  del Némesis: 1.000 / 2.500 / 5.000 eurodólares. Si V le pegó a algún policía, se descuenta la
  mitad "por gastos médicos de los agentes".
- **Contacto "NCPD" en el teléfono**, con su hilo "NCPD - Recompensas": 6 mensajes de pago
  normal y 3 de pago con descuento, en ES (con variantes para V mujer y V hombre) y EN.
- **Inmunidad ante la policía durante las redadas.** Desde que empieza hasta que termina y V
  enfunda el arma (como mucho 60 s después): nada de lo que haga V cuenta como delito, sin
  estrellas de búsqueda aunque una bala perdida le dé a un policía. Los policías de la redada se
  mantienen amistosos con V.
- **Tiroteos simulados con la NCPD** (fuera de cámara). Cada día, cada banda tiene una
  probabilidad (Mod Settings, "Tiroteos con la NCPD", 10%) de que la policía choque con uno de
  sus Némesis. Resultado: escapa (+2 renombre), muere (puede volver, como cualquier muerte
  normal) o lo arrestan 2-5 días. Mientras está arrestado no embosca ni sale en encargos. Todo
  llega como rumores.
- **Causa de muerte de cada Némesis.** Se registra quién le dio el último golpe: V (incluidos
  sus aliados, torretas y drones), la NCPD, otra banda u otra causa (caída, accidente). Se ve en
  el aviso y en el menú NÉMESIS (sección Caídos: "A manos de la NCPD", "A manos de Maelstrom"…).
- **Barra de vida de jefe** del juego para los Némesis vivos (no para su escolta), con su nombre
  completo. Se desactiva con el ajuste `bossBar`.

### Cambiado
- Solo las muertes a manos de V debilitan a la banda en la guerra de bandas. Un remate (disparo
  a la cabeza, explosión, desmembramiento) solo deja muerto para siempre al Némesis si lo dio V.
  Arreglo de compatibilidad con mods que añaden tiroteos entre bandas y policía (NCA).
- **Versión dev y versión release.** La carpeta de trabajo mantiene la ventana de CET
  "Gang Retaliation (dev)" con todos los botones de debug. El zip de `release.py` sale con una
  ventana mínima (campaña, Némesis vivos y muertos, día de juego).
- Nuevos botones de debug: "Debug: force NCPD clash" y "Debug: NCPD raid now".

### Corregido
- **Crash intermitente al huir el último en pie.** La huida se ejecutaba dentro del golpe de V o
  de la muerte de un compañero, a veces sobre un NPC que se estaba muriendo. Ahora se anota y se
  ejecuta en el siguiente tick, después de volver a comprobar que el NPC siga vivo. Además, si V
  y el NPC están pegados, la dirección de huida ya no sale inválida.
- La policía disparaba a V aunque la ayudara en una redada: la banda nacía neutral, así que
  atacarla contaba como delito.
- No se cobraba la recompensa si el Némesis huía a un sitio inalcanzable en mitad de la redada.
- Los mensajes de la policía hablan de "eurodólares" (oficial), no de "eddies" (jerga callejera).
- Se quitó el aviso en pantalla de la recompensa, que repetía lo que ya decía el SMS. Solo sale
  si el SMS no se puede mandar.

### Aviso
- La v1.0.0 publicada en Nexus incluía la ventana de debug completa de CET. Esta versión la
  quita del zip de release.
