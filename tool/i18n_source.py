#!/usr/bin/env python3
"""Single source of every user-visible string, in all supported languages.

Run `python3 tool/i18n_source.py` to regenerate assets/i18n/strings.json,
which both the Flutter UI (lib/core/i18n/i18n.dart) and the native macOS host
(MelodyHost.swift / HudView.swift) read at runtime.

Columns: zh (简体中文, source), en, es, pt, ru, ja, de, fr, id.
Placeholders are {name}; keep them identical in every language.
"""
import json
from pathlib import Path

LANGS = ['zh', 'en', 'es', 'pt', 'ru', 'ja', 'de', 'fr', 'id']

S = {
  # ---- app / window ----
  'app.name': ['旋律键音', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys'],
  'app.windowTitle': ['Melody Keeeys · 旋律键音', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys', 'Melody Keeeys'],
  'app.subtitle': ['旋律键音', 'Keyboard sounds', 'Sonidos de teclado', 'Sons de teclado', 'Звуки клавиатуры', 'キーボード効果音', 'Tastaturklänge', 'Sons de clavier', 'Suara keyboard'],

  # ---- sidebar / status ----
  'nav.general': ['通用', 'General', 'General', 'Geral', 'Общие', '一般', 'Allgemein', 'Général', 'Umum'],
  'nav.sounds': ['音效', 'Sounds', 'Sonidos', 'Sons', 'Звуки', 'サウンド', 'Klänge', 'Sons', 'Suara'],
  'nav.menubar': ['菜单栏', 'Menu bar', 'Barra de menús', 'Barra de menus', 'Строка меню', 'メニューバー', 'Menüleiste', 'Barre des menus', 'Bilah menu'],
  'nav.about': ['关于', 'About', 'Acerca de', 'Sobre', 'О программе', '情報', 'Über', 'À propos', 'Tentang'],
  'nav.engineStatus': ['引擎状态', 'Engine status', 'Estado del motor', 'Estado do motor', 'Состояние движка', 'エンジン状態', 'Engine-Status', 'État du moteur', 'Status mesin'],
  'nav.engineVersion': ['引擎 {version}', 'Engine {version}', 'Motor {version}', 'Motor {version}', 'Движок {version}', 'エンジン {version}', 'Engine {version}', 'Moteur {version}', 'Mesin {version}'],
  'nav.latency': ['延迟 {latency}ms', 'Latency {latency}ms', 'Latencia {latency}ms', 'Latência {latency}ms', 'Задержка {latency} мс', '遅延 {latency}ms', 'Latenz {latency} ms', 'Latence {latency} ms', 'Latensi {latency}ms'],
  'status.running': ['运行中', 'Running', 'En marcha', 'Em execução', 'Работает', '動作中', 'Läuft', 'En marche', 'Berjalan'],
  'status.stopped': ['停止', 'Stopped', 'Detenido', 'Parado', 'Остановлен', '停止', 'Gestoppt', 'Arrêté', 'Berhenti'],
  'status.hookRunning': ['钩子运行中', 'Key hook on', 'Captura activa', 'Captura ativa', 'Перехват активен', 'キー監視中', 'Tastenerfassung an', 'Capture active', 'Penangkap tombol aktif'],
  'status.hookStopped': ['钩子未运行', 'Key hook off', 'Captura inactiva', 'Captura inativa', 'Перехват не активен', 'キー監視停止', 'Tastenerfassung aus', 'Capture inactive', 'Penangkap tombol mati'],

  # ---- common ----
  'common.preview': ['试听', 'Preview', 'Escuchar', 'Ouvir', 'Прослушать', '試聴', 'Anhören', 'Écouter', 'Dengarkan'],
  'common.inUse': ['使用中', 'In use', 'En uso', 'Em uso', 'Используется', '使用中', 'Aktiv', 'Utilisé', 'Dipakai'],
  'common.select': ['选择', 'Select', 'Elegir', 'Escolher', 'Выбрать', '選択', 'Wählen', 'Choisir', 'Pilih'],
  'common.resetDefault': ['恢复默认', 'Reset', 'Restablecer', 'Redefinir', 'Сбросить', 'リセット', 'Zurücksetzen', 'Réinitialiser', 'Atur ulang'],
  'common.followSystem': ['跟随系统', 'System', 'Sistema', 'Sistema', 'Как в системе', 'システムに合わせる', 'Wie System', 'Système', 'Ikuti sistem'],

  # ---- general page ----
  'general.permMac': [
    '需要「辅助功能」权限才能监听全局键盘。请前往 系统设置 → 隐私与安全性 → 辅助功能，勾选 Melody Keeeys 后重试。',
    'Accessibility permission is needed to hear the keyboard. Go to System Settings → Privacy & Security → Accessibility, turn on Melody Keeeys, then retry.',
    'Se necesita el permiso de Accesibilidad para oír el teclado. Ve a Ajustes del Sistema → Privacidad y seguridad → Accesibilidad, activa Melody Keeeys y vuelve a intentarlo.',
    'É necessária a permissão de Acessibilidade para ouvir o teclado. Vá a Ajustes do Sistema → Privacidade e Segurança → Acessibilidade, ative o Melody Keeeys e tente de novo.',
    'Нужно разрешение «Универсальный доступ», чтобы слышать клавиатуру. Откройте Системные настройки → Конфиденциальность и безопасность → Универсальный доступ, включите Melody Keeeys и повторите.',
    'キーボードを検知するにはアクセシビリティの許可が必要です。システム設定 → プライバシーとセキュリティ → アクセシビリティで Melody Keeeys をオンにしてから再試行してください。',
    'Für die Tastaturerkennung ist die Bedienungshilfen-Berechtigung nötig. Öffne Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen, aktiviere Melody Keeeys und versuche es erneut.',
    'L’autorisation Accessibilité est nécessaire pour entendre le clavier. Ouvrez Réglages Système → Confidentialité et sécurité → Accessibilité, activez Melody Keeeys, puis réessayez.',
    'Izin Aksesibilitas diperlukan untuk mendengar keyboard. Buka Pengaturan Sistem → Privasi & Keamanan → Aksesibilitas, aktifkan Melody Keeeys, lalu coba lagi.'],
  'general.permLinux': [
    '需要读取 /dev/input 设备（input 用户组）。执行 sudo usermod -aG input $USER 并重新登录后重试。',
    'Reading /dev/input is required (input group). Run sudo usermod -aG input $USER, log in again, then retry.',
    'Se necesita leer /dev/input (grupo input). Ejecuta sudo usermod -aG input $USER, vuelve a iniciar sesión y reinténtalo.',
    'É necessário ler /dev/input (grupo input). Execute sudo usermod -aG input $USER, inicie sessão de novo e tente outra vez.',
    'Нужен доступ к /dev/input (группа input). Выполните sudo usermod -aG input $USER, перезайдите в систему и повторите.',
    '/dev/input の読み取り権限（input グループ）が必要です。sudo usermod -aG input $USER を実行し、再ログインしてから再試行してください。',
    'Lesezugriff auf /dev/input ist nötig (Gruppe input). Führe sudo usermod -aG input $USER aus, melde dich neu an und versuche es erneut.',
    'La lecture de /dev/input est requise (groupe input). Exécutez sudo usermod -aG input $USER, reconnectez-vous puis réessayez.',
    'Perlu akses baca /dev/input (grup input). Jalankan sudo usermod -aG input $USER, masuk ulang, lalu coba lagi.'],
  'general.openSettings': ['打开设置', 'Open Settings', 'Abrir Ajustes', 'Abrir Ajustes', 'Открыть настройки', '設定を開く', 'Einstellungen öffnen', 'Ouvrir les Réglages', 'Buka Pengaturan'],
  'general.recheck': ['重新检查', 'Check again', 'Comprobar de nuevo', 'Verificar de novo', 'Проверить снова', '再確認', 'Erneut prüfen', 'Revérifier', 'Periksa lagi'],
  'general.systemTitle': ['系统与启动', 'System & startup', 'Sistema e inicio', 'Sistema e arranque', 'Система и запуск', 'システムと起動', 'System & Start', 'Système et démarrage', 'Sistem & startup'],
  'general.coreBadge': ['核心配置', 'Core', 'Básico', 'Essencial', 'Основное', '基本設定', 'Kern', 'Essentiel', 'Inti'],
  'general.engineStatus': ['引擎状态 {latency}ms · 引擎 {version}', 'Engine {latency}ms · {version}', 'Motor {latency}ms · {version}', 'Motor {latency}ms · {version}', 'Движок {latency} мс · {version}', 'エンジン {latency}ms · {version}', 'Engine {latency} ms · {version}', 'Moteur {latency} ms · {version}', 'Mesin {latency}ms · {version}'],
  'general.soundEngine': ['声音引擎', 'Sound engine', 'Motor de sonido', 'Motor de som', 'Звуковой движок', 'サウンドエンジン', 'Sound-Engine', 'Moteur sonore', 'Mesin suara'],
  'general.soundEngineTip': ['关闭后全局按键将不再播放音效', 'When off, key presses make no sound', 'Si está desactivado, las teclas no suenan', 'Desligado, as teclas não emitem som', 'Если выключено, нажатия не озвучиваются', 'オフにするとキー入力で音が鳴りません', 'Aus: Tastendrücke bleiben stumm', 'Désactivé, les touches restent muettes', 'Jika mati, tombol tidak berbunyi'],
  'general.launchAtStartup': ['开机自动启动', 'Launch at login', 'Abrir al iniciar sesión', 'Abrir ao iniciar sessão', 'Запускать при входе', 'ログイン時に起動', 'Bei Anmeldung starten', 'Ouvrir à la connexion', 'Buka saat masuk'],
  'general.launchTip': ['登录后自动在后台启动 Melody Keeeys', 'Start Melody Keeeys in the background after you log in', 'Inicia Melody Keeeys en segundo plano al iniciar sesión', 'Inicia o Melody Keeeys em segundo plano ao iniciar sessão', 'Запускать Melody Keeeys в фоне после входа', 'ログイン後に Melody Keeeys をバックグラウンドで起動します', 'Melody Keeeys nach der Anmeldung im Hintergrund starten', 'Lance Melody Keeeys en arrière-plan à la connexion', 'Jalankan Melody Keeeys di latar belakang setelah masuk'],
  'general.theme': ['外观主题', 'Appearance', 'Apariencia', 'Aparência', 'Оформление', '外観', 'Erscheinungsbild', 'Apparence', 'Tampilan'],
  'general.language': ['界面语言', 'Language', 'Idioma', 'Idioma', 'Язык', '言語', 'Sprache', 'Langue', 'Bahasa'],
  'general.languageTip': ['设置窗口、托盘面板与菜单使用的语言', 'Language for settings, the tray panel and menus', 'Idioma de los ajustes, el panel y los menús', 'Idioma dos ajustes, do painel e dos menus', 'Язык настроек, панели и меню', '設定・トレイパネル・メニューの表示言語', 'Sprache für Einstellungen, Leistenpanel und Menüs', 'Langue des réglages, du panneau et des menus', 'Bahasa untuk pengaturan, panel, dan menu'],
  'general.hotkeysTitle': ['全局热键映射', 'Global hotkeys', 'Atajos globales', 'Atalhos globais', 'Глобальные сочетания клавиш', 'グローバルホットキー', 'Globale Kurzbefehle', 'Raccourcis globaux', 'Pintasan global'],
  'general.systemBadge': ['系统级', 'System-wide', 'Global', 'Global', 'Системные', 'システム全体', 'Systemweit', 'Global', 'Seluruh sistem'],
  'general.muteHotkey': ['全局静音 / 恢复输出', 'Mute / unmute', 'Silenciar / activar sonido', 'Silenciar / reativar som', 'Выключить / включить звук', 'ミュート / 解除', 'Stumm / Ton an', 'Couper / rétablir le son', 'Bisukan / bunyikan'],
  'general.muteTip': ['随时一键切断物理键盘声音', 'Cut keyboard sounds with one shortcut', 'Corta los sonidos del teclado con un atajo', 'Corta os sons do teclado com um atalho', 'Отключайте звуки клавиатуры одним сочетанием', 'ワンキーでキーボード音をオフ', 'Tastaturklänge mit einem Kurzbefehl abschalten', 'Coupez les sons du clavier d’un raccourci', 'Matikan suara keyboard dengan satu pintasan'],
  'general.cycleHotkey': ['快速轮换下一个按键声音包', 'Switch to the next sound pack', 'Cambiar al siguiente paquete', 'Mudar para o pacote seguinte', 'Следующий набор звуков', '次のサウンドパックへ', 'Zum nächsten Klangpaket', 'Pack de sons suivant', 'Beralih ke paket suara berikutnya'],
  'general.cycleTip': ['在已加载的轴体音效配置中随时轮换', 'Cycle through the loaded sound packs', 'Recorre los paquetes de sonido cargados', 'Percorre os pacotes de som carregados', 'Перебирать загруженные наборы звуков', '読み込んだサウンドパックを順に切り替えます', 'Durch die geladenen Klangpakete wechseln', 'Parcourt les packs de sons chargés', 'Bergilir di antara paket suara yang dimuat'],
  'general.antiGhostTitle': ['触发防冲突与按键响应', 'Triggering & key response', 'Disparo y respuesta de teclas', 'Disparo e resposta das teclas', 'Срабатывание и отклик клавиш', 'トリガーとキー応答', 'Auslösung & Tastenreaktion', 'Déclenchement et réponse', 'Pemicu & respons tombol'],
  'general.acousticBadge': ['声学抑制', 'Damping', 'Amortiguación', 'Amortecimento', 'Подавление', '音響抑制', 'Dämpfung', 'Atténuation', 'Peredaman'],
  'general.antiGhostWindow': ['连击抑制窗口', 'Repeat suppression window', 'Ventana anti-repetición', 'Janela anti-repetição', 'Окно подавления повторов', '連打抑制ウィンドウ', 'Wiederholsperre', 'Fenêtre anti-répétition', 'Jeda anti-ulang'],
  'general.modifierRepeat': ['修饰键长按连发声', 'Repeat sound on held modifiers', 'Repetir sonido en modificadores', 'Repetir som em modificadores', 'Повтор звука для модификаторов', '修飾キー長押しで連続音', 'Ton bei gehaltenen Sondertasten wiederholen', 'Répéter le son des modificateurs', 'Ulangi suara tombol pengubah'],
  'general.modifierRepeatTip': ['长按 Shift / Control 等修饰键时持续循环修饰键行程音', 'Keep repeating the modifier sound while Shift / Control is held', 'Repite el sonido mientras mantienes Shift / Control', 'Repete o som enquanto Shift / Control está premido', 'Повторять звук, пока зажаты Shift / Control', 'Shift / Control などを押し続ける間、音を繰り返します', 'Wiederholt den Ton, solange Shift / Control gedrückt ist', 'Répète le son tant que Maj / Contrôle est maintenu', 'Ulangi suara selama Shift / Control ditahan'],
  'general.releaseSound': ['松键上行程音', 'Key release sound', 'Sonido al soltar', 'Som ao soltar', 'Звук отпускания', 'キーを離す音', 'Ton beim Loslassen', 'Son au relâchement', 'Suara saat dilepas'],
  'general.releaseSoundTip': ['模拟轴体弹起时的回弹声', 'Simulates the switch springing back up', 'Simula el rebote del interruptor', 'Simula o retorno do switch', 'Имитирует возврат переключателя', 'スイッチが戻るときの音を再現します', 'Simuliert das Zurückfedern des Schalters', 'Simule le retour du switch', 'Meniru pantulan switch saat kembali'],
  'general.releaseVolume': ['回弹音量', 'Release volume', 'Volumen al soltar', 'Volume ao soltar', 'Громкость отпускания', '離す音の音量', 'Loslass-Lautstärke', 'Volume du relâchement', 'Volume lepas'],
  'general.smartMuteTitle': ['智能静音与防干扰应用列表', 'Smart mute for apps', 'Silencio inteligente por app', 'Silêncio inteligente por app', 'Умное отключение для приложений', 'アプリ別スマートミュート', 'Intelligentes Stummschalten pro App', 'Sourdine intelligente par app', 'Bisu pintar per aplikasi'],
  'general.comingSoon': ['即将推出', 'Coming soon', 'Próximamente', 'Em breve', 'Скоро', '近日公開', 'Demnächst', 'Bientôt', 'Segera hadir'],
  'general.smartMuteTip': [
    '目标进程获得操作系统焦点时自动切断声音输出。\n该功能将在后续版本提供：会议、游戏与 DAW 独占混音场景自动静音。',
    'Mutes sounds automatically while chosen apps are in focus.\nComing in a later version: auto-mute for meetings, games and DAWs.',
    'Silencia automáticamente mientras las apps elegidas están en primer plano.\nLlegará en una versión futura: reuniones, juegos y DAW.',
    'Silencia automaticamente enquanto as apps escolhidas estão em primeiro plano.\nChega numa versão futura: reuniões, jogos e DAW.',
    'Автоматически отключает звук, пока выбранные приложения активны.\nПоявится в следующих версиях: встречи, игры и DAW.',
    '指定したアプリが前面にあるとき自動でミュートします。\n今後のバージョンで提供予定：会議・ゲーム・DAW。',
    'Schaltet automatisch stumm, solange gewählte Apps im Vordergrund sind.\nKommt in einer späteren Version: Meetings, Spiele und DAWs.',
    'Coupe le son automatiquement quand les apps choisies sont au premier plan.\nPrévu dans une version future : réunions, jeux et DAW.',
    'Membisukan otomatis saat aplikasi pilihan sedang aktif.\nHadir di versi mendatang: rapat, game, dan DAW.'],
  'general.factoryReset': ['恢复默认出厂设置', 'Restore defaults', 'Restaurar valores', 'Repor predefinições', 'Восстановить настройки', '初期設定に戻す', 'Standard wiederherstellen', 'Rétablir les réglages', 'Pulihkan bawaan'],
  'general.testPad': ['声学测试跳线', 'Sound test pad', 'Zona de prueba', 'Área de teste', 'Поле для проверки', 'サウンドテスト', 'Klangtest', 'Zone de test', 'Area uji suara'],
  'general.testPadTip': ['全局钩子运行时，在应用外打字也会发声；此输入框仅用于快速试音。', 'While the key hook runs you hear typing everywhere; this box is just for a quick test.', 'Con la captura activa suenan todas las teclas; este cuadro es solo para probar.', 'Com a captura ativa ouve todas as teclas; esta caixa é só para testar.', 'Когда перехват активен, звучит набор везде; это поле только для проверки.', 'キー監視中はどこで入力しても鳴ります。この欄は試し打ち用です。', 'Bei aktiver Erfassung klingt jede Eingabe; dieses Feld ist nur zum Testen.', 'Capture active, toute frappe sonne ; ce champ sert juste à tester.', 'Saat penangkap aktif, semua ketikan berbunyi; kotak ini hanya untuk uji cepat.'],
  'general.keystrokesTotal': ['累计敲击 {n}', '{n} keystrokes', '{n} pulsaciones', '{n} toques', 'Нажатий: {n}', '打鍵数 {n}', '{n} Anschläge', '{n} frappes', '{n} ketukan'],
  'general.testPadHint': ['在此区域敲击键盘或输入文字，实时试听当前音效包的敲击响应…', 'Type here to hear the current sound pack…', 'Escribe aquí para oír el paquete actual…', 'Escreva aqui para ouvir o pacote atual…', 'Печатайте здесь, чтобы услышать текущий набор…', 'ここに入力して現在のサウンドを試聴…', 'Hier tippen, um das aktuelle Paket zu hören…', 'Tapez ici pour écouter le pack actuel…', 'Ketik di sini untuk mendengar paket saat ini…'],

  # ---- menu bar page ----
  'menubar.clickTitle': ['点击与手势绑定', 'Clicks', 'Clics', 'Cliques', 'Щелчки', 'クリック操作', 'Klicks', 'Clics', 'Klik'],
  'menubar.nativeBadge': ['原生钩子', 'Native', 'Nativo', 'Nativo', 'Нативно', 'ネイティブ', 'Nativ', 'Natif', 'Native'],
  'menubar.leftClick': ['左键行为（主要触发方式）', 'Left click', 'Clic izquierdo', 'Clique esquerdo', 'Левый щелчок', '左クリック', 'Linksklick', 'Clic gauche', 'Klik kiri'],
  'menubar.linuxTip': [
    'Linux 部分桌面（GNOME + AppIndicator）下左键会直接打开上下文菜单。',
    'On some Linux desktops (GNOME + AppIndicator) left click opens the context menu instead.',
    'En algunos escritorios Linux (GNOME + AppIndicator) el clic izquierdo abre el menú contextual.',
    'Em alguns ambientes Linux (GNOME + AppIndicator) o clique esquerdo abre o menu de contexto.',
    'В некоторых средах Linux (GNOME + AppIndicator) левый щелчок открывает контекстное меню.',
    '一部の Linux デスクトップ（GNOME + AppIndicator）では左クリックでメニューが開きます。',
    'Auf manchen Linux-Desktops (GNOME + AppIndicator) öffnet der Linksklick das Kontextmenü.',
    'Sur certains bureaux Linux (GNOME + AppIndicator), le clic gauche ouvre le menu contextuel.',
    'Di beberapa desktop Linux (GNOME + AppIndicator) klik kiri membuka menu konteks.'],
  'menubar.cycleNext': ['轮换下一个音效', 'Next sound pack', 'Siguiente paquete', 'Pacote seguinte', 'Следующий набор', '次のサウンド', 'Nächstes Klangpaket', 'Pack suivant', 'Paket berikutnya'],
  'menubar.cycleNextTip': ['立即切换声音配置，无 UI 打扰，快速而带感。', 'Switch sounds instantly, no window in the way.', 'Cambia el sonido al instante, sin ventanas.', 'Muda o som na hora, sem janelas.', 'Мгновенная смена звука без окон.', 'ウィンドウを開かずに即座に切り替えます。', 'Wechselt sofort, ohne Fenster.', 'Change de son instantanément, sans fenêtre.', 'Ganti suara seketika, tanpa jendela.'],
  'menubar.showPanel': ['显示托盘面板', 'Show tray panel', 'Mostrar panel', 'Mostrar painel', 'Показать панель', 'トレイパネルを表示', 'Leistenpanel zeigen', 'Afficher le panneau', 'Tampilkan panel'],
  'menubar.showPanelTip': ['弹出紧凑的悬浮调音面板：滑杆、音效包与预设。', 'Opens a compact panel with sound packs and controls.', 'Abre un panel compacto con paquetes y controles.', 'Abre um painel compacto com pacotes e controlos.', 'Открывает компактную панель с наборами и настройками.', 'サウンドパックと操作をまとめた小さなパネルを開きます。', 'Öffnet ein kompaktes Panel mit Klangpaketen und Reglern.', 'Ouvre un panneau compact avec les packs et réglages.', 'Membuka panel ringkas berisi paket suara dan kontrol.'],
  'menubar.contextMenu': ['右键上下文菜单', 'Right-click menu', 'Menú del clic derecho', 'Menu do clique direito', 'Меню правого щелчка', '右クリックメニュー', 'Rechtsklickmenü', 'Menu clic droit', 'Menu klik kanan'],
  'menubar.contextMenuTip': ['快速面板、声音引擎开关与设置入口（系统级菜单）', 'Tray panel, sound engine switch and settings (system menu)', 'Panel, interruptor del motor y ajustes (menú del sistema)', 'Painel, interruptor do motor e ajustes (menu do sistema)', 'Панель, переключатель движка и настройки (системное меню)', 'パネル・エンジンのオンオフ・設定（システムメニュー）', 'Panel, Engine-Schalter und Einstellungen (Systemmenü)', 'Panneau, moteur et réglages (menu système)', 'Panel, sakelar mesin, dan pengaturan (menu sistem)'],
  'menubar.systemMenu': ['系统级菜单', 'System menu', 'Menú del sistema', 'Menu do sistema', 'Системное меню', 'システムメニュー', 'Systemmenü', 'Menu système', 'Menu sistem'],
  'menubar.iconTitle': ['菜单栏图标', 'Menu bar icon', 'Icono de la barra', 'Ícone da barra', 'Значок в строке меню', 'メニューバーアイコン', 'Menüleisten-Symbol', 'Icône de la barre', 'Ikon bilah menu'],
  'menubar.iconBadge': ['Lucide 图标库', 'Lucide icons', 'Iconos Lucide', 'Ícones Lucide', 'Значки Lucide', 'Lucide アイコン', 'Lucide-Symbole', 'Icônes Lucide', 'Ikon Lucide'],
  'menubar.iconTip': ['从 Lucide 图标库中选择托盘/菜单栏图标', 'Pick the tray / menu bar icon from Lucide', 'Elige el icono de la barra entre los de Lucide', 'Escolha o ícone da barra entre os do Lucide', 'Выберите значок из набора Lucide', 'Lucide からアイコンを選びます', 'Symbol aus Lucide wählen', 'Choisissez l’icône parmi Lucide', 'Pilih ikon dari Lucide'],

  # ---- sounds page ----
  'sounds.listTitle': ['音效包列表', 'Sound packs', 'Paquetes de sonido', 'Pacotes de som', 'Наборы звуков', 'サウンドパック', 'Klangpakete', 'Packs de sons', 'Paket suara'],
  'sounds.loadedBadge': ['已加载 {n} 个', '{n} loaded', '{n} cargados', '{n} carregados', 'Загружено: {n}', '{n} 個読み込み済み', '{n} geladen', '{n} chargés', '{n} dimuat'],
  'sounds.switchTo': ['切换到此音效包', 'Use this pack', 'Usar este paquete', 'Usar este pacote', 'Выбрать этот набор', 'このパックを使う', 'Dieses Paket nutzen', 'Utiliser ce pack', 'Pakai paket ini'],
  'sounds.dspTitle': ['声学主引擎 DSP', 'Engine DSP', 'DSP del motor', 'DSP do motor', 'DSP движка', 'エンジン DSP', 'Engine-DSP', 'DSP du moteur', 'DSP mesin'],
  'sounds.volume': ['音量补偿', 'Volume', 'Volumen', 'Volume', 'Громкость', '音量', 'Lautstärke', 'Volume', 'Volume'],
  'sounds.pitchJitter': ['音高抖动', 'Pitch variation', 'Variación de tono', 'Variação de tom', 'Разброс высоты', 'ピッチのゆらぎ', 'Tonhöhen-Variation', 'Variation de hauteur', 'Variasi nada'],
  'sounds.testBench': ['交互试音台', 'Try it', 'Pruébalo', 'Experimente', 'Попробуйте', '試し打ち', 'Ausprobieren', 'Essayez', 'Coba'],
  'sounds.boxKeystrokes': ['本框敲击 {n}', '{n} here', '{n} aquí', '{n} aqui', 'Здесь: {n}', 'この欄 {n}', '{n} hier', '{n} ici', '{n} di sini'],
  'sounds.testHint': ['在此输入以实时试音（试试快速连按 Shift、空格与回退键）…', 'Type here to test (try fast Shift, Space and Backspace)…', 'Escribe para probar (prueba Shift, Espacio y Retroceso rápido)…', 'Escreva para testar (experimente Shift, Espaço e Retrocesso rápido)…', 'Печатайте для проверки (попробуйте быстро Shift, пробел и Backspace)…', 'ここで試し打ち（Shift・スペース・Backspace の連打もどうぞ）…', 'Hier tippen (schnell Shift, Leertaste und Rücktaste probieren)…', 'Tapez pour tester (essayez Maj, Espace et Retour vite)…', 'Ketik untuk mencoba (coba Shift, Spasi, dan Backspace cepat)…'],
  'sounds.engineOffHint': ['声音引擎已关闭，开启后可在此试音。', 'The sound engine is off. Turn it on to test here.', 'El motor está apagado. Actívalo para probar aquí.', 'O motor está desligado. Ligue-o para testar aqui.', 'Звуковой движок выключен. Включите его для проверки.', 'サウンドエンジンがオフです。オンにすると試せます。', 'Die Sound-Engine ist aus. Zum Testen einschalten.', 'Le moteur est coupé. Activez-le pour tester ici.', 'Mesin suara mati. Nyalakan untuk mencoba di sini.'],
  'layer.alpha': ['字母键 A-Z', 'Letters A-Z', 'Letras A-Z', 'Letras A-Z', 'Буквы A-Z', '文字キー A-Z', 'Buchstaben A-Z', 'Lettres A-Z', 'Huruf A-Z'],
  'layer.space': ['空格键', 'Space', 'Espacio', 'Espaço', 'Пробел', 'スペース', 'Leertaste', 'Espace', 'Spasi'],
  'layer.enter': ['回车/退格', 'Return / Backspace', 'Intro / Retroceso', 'Enter / Retrocesso', 'Enter / Backspace', 'Return / Backspace', 'Return / Rücktaste', 'Entrée / Retour', 'Enter / Backspace'],
  'layer.modifier': ['修饰键', 'Modifiers', 'Modificadores', 'Modificadores', 'Модификаторы', '修飾キー', 'Sondertasten', 'Modificateurs', 'Tombol pengubah'],
  'layer.nav': ['功能/导航键', 'Function / navigation', 'Función / navegación', 'Função / navegação', 'Функции / навигация', 'ファンクション / 移動', 'Funktion / Navigation', 'Fonction / navigation', 'Fungsi / navigasi'],

  # ---- about ----
  'about.tagline': ['让每一次敲击都有声音', 'Every keystroke, a sound', 'Cada tecla, un sonido', 'Cada tecla, um som', 'У каждого нажатия свой звук', 'ひと打ちごとに音を', 'Jeder Anschlag ein Klang', 'Chaque frappe, un son', 'Setiap ketukan, satu suara'],
  'about.techStack': ['技术栈', 'Built with', 'Tecnología', 'Tecnologia', 'Технологии', '技術スタック', 'Technik', 'Technologies', 'Teknologi'],
  'about.audioEngine': ['音频引擎', 'Audio engine', 'Motor de audio', 'Motor de áudio', 'Аудиодвижок', 'オーディオエンジン', 'Audio-Engine', 'Moteur audio', 'Mesin audio'],
  'about.audioEngineDetail': [
    'miniaudio {version} · dart:ffi 直连，内存预解码与复音引擎，输出延迟约 {latency}ms',
    'miniaudio {version} · dart:ffi, pre-decoded samples and polyphony, about {latency}ms output latency',
    'miniaudio {version} · dart:ffi, muestras predescodificadas y polifonía, unos {latency}ms de latencia',
    'miniaudio {version} · dart:ffi, amostras pré-descodificadas e polifonia, cerca de {latency}ms de latência',
    'miniaudio {version} · dart:ffi, предекодированные сэмплы и полифония, задержка около {latency} мс',
    'miniaudio {version} · dart:ffi、デコード済みサンプルとポリフォニー、出力遅延 約 {latency}ms',
    'miniaudio {version} · dart:ffi, vordekodierte Samples und Polyfonie, etwa {latency} ms Latenz',
    'miniaudio {version} · dart:ffi, échantillons prédécodés et polyphonie, environ {latency} ms de latence',
    'miniaudio {version} · dart:ffi, sampel pra-dekode dan polifoni, latensi sekitar {latency}ms'],
  'about.keyHook': ['全局键盘钩子', 'Global key hook', 'Captura global de teclas', 'Captura global de teclas', 'Глобальный перехват клавиш', 'グローバルキー監視', 'Globale Tastenerfassung', 'Capture globale des touches', 'Penangkap tombol global'],
  'about.keyHookDetail': ['macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev（input 组）', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (input group)', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (grupo input)', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (grupo input)', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (группа input)', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev（input グループ）', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (Gruppe input)', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (groupe input)', 'macOS CGEventTap · Windows WH_KEYBOARD_LL · Linux evdev (grup input)'],
  'about.framework': ['应用框架', 'App framework', 'Framework', 'Framework', 'Фреймворк', 'アプリフレームワーク', 'App-Framework', 'Framework', 'Kerangka aplikasi'],
  'about.licenses': ['开源许可', 'Open-source licenses', 'Licencias de código abierto', 'Licenças open source', 'Лицензии открытого ПО', 'オープンソースライセンス', 'Open-Source-Lizenzen', 'Licences open source', 'Lisensi sumber terbuka'],

  # ---- settings enums ----
  'theme.light': ['浅色', 'Light', 'Claro', 'Claro', 'Светлое', 'ライト', 'Hell', 'Clair', 'Terang'],
  'theme.dark': ['深色', 'Dark', 'Oscuro', 'Escuro', 'Тёмное', 'ダーク', 'Dunkel', 'Sombre', 'Gelap'],
  'latency.ultra': ['极速 (2ms)', 'Fastest (2ms)', 'Rapidísimo (2ms)', 'Rapidíssimo (2ms)', 'Максимум (2 мс)', '最速 (2ms)', 'Schnellste (2 ms)', 'Ultra (2 ms)', 'Tercepat (2ms)'],
  'latency.native': ['标准 (5ms)', 'Standard (5ms)', 'Estándar (5ms)', 'Padrão (5ms)', 'Стандарт (5 мс)', '標準 (5ms)', 'Standard (5 ms)', 'Standard (5 ms)', 'Standar (5ms)'],
  'latency.safe': ['稳健 (21ms)', 'Stable (21ms)', 'Estable (21ms)', 'Estável (21ms)', 'Надёжно (21 мс)', '安定 (21ms)', 'Stabil (21 ms)', 'Stable (21 ms)', 'Stabil (21ms)'],
  'icon.keyboard': ['键盘', 'Keyboard', 'Teclado', 'Teclado', 'Клавиатура', 'キーボード', 'Tastatur', 'Clavier', 'Keyboard'],
  'icon.keyboard-music': ['键盘音符', 'Keyboard music', 'Teclado musical', 'Teclado musical', 'Музыкальная клавиатура', '鍵盤', 'Musiktastatur', 'Clavier musical', 'Keyboard musik'],
  'icon.command': ['命令', 'Command', 'Comando', 'Comando', 'Command', 'コマンド', 'Befehl', 'Commande', 'Command'],
  'icon.line-squiggle': ['涂鸦线', 'Squiggle', 'Garabato', 'Rabisco', 'Завиток', '波線', 'Kringel', 'Gribouillis', 'Coretan'],
  'icon.gamepad-directional': ['方向键', 'D-pad', 'Cruceta', 'Direcional', 'Крестовина', '十字キー', 'Steuerkreuz', 'Croix directionnelle', 'D-pad'],
  'icon.tv': ['电视', 'TV', 'TV', 'TV', 'ТВ', 'テレビ', 'TV', 'TV', 'TV'],
  'icon.balloon': ['气球', 'Balloon', 'Globo', 'Balão', 'Шарик', '風船', 'Ballon', 'Ballon', 'Balon'],

  # ---- tray menu / tooltip (native + Dart) ----
  'tray.nowPlaying': ['正在使用：{pack}', 'Now playing: {pack}', 'Sonando: {pack}', 'A tocar: {pack}', 'Сейчас: {pack}', '使用中：{pack}', 'Aktiv: {pack}', 'En cours : {pack}', 'Sedang dipakai: {pack}'],
  'tray.engineOn': ['声音引擎：已开启', 'Sound engine: on', 'Motor de sonido: activado', 'Motor de som: ligado', 'Звуковой движок: вкл.', 'サウンドエンジン：オン', 'Sound-Engine: an', 'Moteur sonore : activé', 'Mesin suara: aktif'],
  'tray.openPanel': ['打开托盘面板', 'Open tray panel', 'Abrir panel', 'Abrir painel', 'Открыть панель', 'トレイパネルを開く', 'Leistenpanel öffnen', 'Ouvrir le panneau', 'Buka panel'],
  'tray.settings': ['设置…', 'Settings…', 'Ajustes…', 'Ajustes…', 'Настройки…', '設定…', 'Einstellungen …', 'Réglages…', 'Pengaturan…'],
  'tray.quit': ['退出 Melody Keeeys', 'Quit Melody Keeeys', 'Salir de Melody Keeeys', 'Sair do Melody Keeeys', 'Завершить Melody Keeeys', 'Melody Keeeys を終了', 'Melody Keeeys beenden', 'Quitter Melody Keeeys', 'Keluar dari Melody Keeeys'],
  'tray.noPermission': ['未开启辅助功能权限，打字不会有声音', 'Accessibility is off, typing makes no sound', 'Accesibilidad desactivada: escribir no suena', 'Acessibilidade desligada: escrever não faz som', 'Универсальный доступ выключен: набор без звука', 'アクセシビリティがオフのため入力しても鳴りません', 'Bedienungshilfen aus: Tippen bleibt stumm', 'Accessibilité désactivée : la frappe est muette', 'Aksesibilitas mati, mengetik tidak berbunyi'],

  # ---- tray panel (HUD) ----
  'hud.title': ['托盘面板', 'Tray panel', 'Panel', 'Painel', 'Панель', 'トレイパネル', 'Leistenpanel', 'Panneau', 'Panel'],
  'hud.engineRunning': ['音频引擎运行中  {latency}ms', 'Audio engine on  {latency}ms', 'Motor de audio activo  {latency}ms', 'Motor de áudio ativo  {latency}ms', 'Аудиодвижок работает  {latency} мс', 'オーディオエンジン動作中  {latency}ms', 'Audio-Engine läuft  {latency} ms', 'Moteur audio actif  {latency} ms', 'Mesin audio aktif  {latency}ms'],
  'hud.engineMuted': ['音频引擎已静音', 'Audio engine muted', 'Motor de audio silenciado', 'Motor de áudio silenciado', 'Аудиодвижок без звука', 'オーディオエンジンはミュート中', 'Audio-Engine stumm', 'Moteur audio muet', 'Mesin audio dibisukan'],
  'hud.inUse': ['正在使用', 'Now playing', 'Sonando', 'A tocar', 'Сейчас', '使用中', 'Aktiv', 'En cours', 'Sedang dipakai'],
  'hud.openSettings': ['打开设置…', 'Open Settings…', 'Abrir ajustes…', 'Abrir ajustes…', 'Открыть настройки…', '設定を開く…', 'Einstellungen öffnen …', 'Ouvrir les réglages…', 'Buka pengaturan…'],
  'hud.noPermTitle': ['未开启辅助功能权限', 'Accessibility is off', 'Accesibilidad desactivada', 'Acessibilidade desligada', 'Универсальный доступ выключен', 'アクセシビリティがオフです', 'Bedienungshilfen sind aus', 'Accessibilité désactivée', 'Aksesibilitas mati'],
  'hud.noPermBody': [
    '不开启时打字不会有任何声音。请在「系统设置 → 隐私与安全性 → 辅助功能」中勾选旋律键音，勾选后几秒内自动生效，无需重启。',
    'Without it, typing makes no sound at all. Turn on Melody Keeeys in System Settings → Privacy & Security → Accessibility. It works within seconds, no restart needed.',
    'Sin este permiso, escribir no suena. Activa Melody Keeeys en Ajustes del Sistema → Privacidad y seguridad → Accesibilidad. Funciona en segundos, sin reiniciar.',
    'Sem esta permissão, escrever não faz som. Ative o Melody Keeeys em Ajustes do Sistema → Privacidade e Segurança → Acessibilidade. Funciona em segundos, sem reiniciar.',
    'Без него набор текста совсем не звучит. Включите Melody Keeeys в Системных настройках → Конфиденциальность и безопасность → Универсальный доступ. Заработает через несколько секунд, без перезапуска.',
    'オフのままでは入力しても音が鳴りません。システム設定 → プライバシーとセキュリティ → アクセシビリティで Melody Keeeys をオンにしてください。数秒で有効になり、再起動は不要です。',
    'Ohne sie bleibt jede Eingabe stumm. Aktiviere Melody Keeeys unter Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen. Wirkt nach wenigen Sekunden, kein Neustart nötig.',
    'Sans elle, la frappe reste muette. Activez Melody Keeeys dans Réglages Système → Confidentialité et sécurité → Accessibilité. Effectif en quelques secondes, sans redémarrage.',
    'Tanpa izin ini, mengetik tidak berbunyi sama sekali. Aktifkan Melody Keeeys di Pengaturan Sistem → Privasi & Keamanan → Aksesibilitas. Berlaku dalam beberapa detik, tanpa mulai ulang.'],
  'hud.grant': ['去开启权限', 'Turn on access', 'Activar permiso', 'Ativar permissão', 'Включить доступ', '許可をオンにする', 'Zugriff erlauben', 'Activer l’accès', 'Aktifkan izin'],
  'hud.noPermStatus': ['无辅助功能权限，按键无声', 'No Accessibility access, keys are silent', 'Sin Accesibilidad, teclas en silencio', 'Sem Acessibilidade, teclas em silêncio', 'Нет доступа, клавиши без звука', 'アクセシビリティなし：キー音なし', 'Keine Bedienungshilfen: Tasten stumm', 'Pas d’accès Accessibilité : touches muettes', 'Tanpa Aksesibilitas, tombol bisu'],

  # ---- sound pack descriptions ----
  'pack.cherry_mx_blue': ['经典青轴脆响，60g 触发段落感，高频咔嗒声干净利落。', 'Classic clicky blue switch: 60g tactile bump and a crisp, clean click.', 'Clásico interruptor azul: 60 g con tope táctil y un clic nítido.', 'Clássico switch azul: 60 g com ressalto tátil e um clique nítido.', 'Классический синий свитч: 60 г, тактильный щелчок, чистый звонкий клик.', '定番の青軸。60g のクリック感と歯切れのよい高音。', 'Klassischer blauer Schalter: 60 g, taktil, klarer heller Klick.', 'Switch bleu classique : 60 g, tactile, clic net et clair.', 'Switch biru klasik: 60 g, taktil, klik renyah dan bersih.'],
  'pack.gateron_oil_king': ['佳达隆墨轴线性重压，深沉厚实的触底声。', 'Gateron Black Ink: heavy linear press with a deep, solid bottom-out.', 'Gateron Black Ink: lineal pesado con un fondo grave y sólido.', 'Gateron Black Ink: linear pesado com um batente grave e sólido.', 'Gateron Black Ink: тяжёлый линейный ход и глубокий плотный удар.', 'Gateron 墨軸：重めのリニア、深く厚い底打ち音。', 'Gateron Black Ink: schwer und linear, tiefer satter Anschlag.', 'Gateron Black Ink : linéaire lourd, fond de course grave et plein.', 'Gateron Black Ink: linear berat, bunyi dasar dalam dan padat.'],
  'pack.holy_panda': ['67g 圆润凸点，肉感十足的弹压敲击。', '67g rounded tactile bump, a full and meaty press.', 'Tope táctil redondo de 67 g, pulsación llena y carnosa.', 'Ressalto tátil redondo de 67 g, toque cheio e encorpado.', 'Округлый тактильный бугорок 67 г, сочное нажатие.', '67g の丸いタクタイル、肉厚な打鍵感。', '67 g, runder taktiler Punkt, voller satter Anschlag.', 'Bosse tactile ronde de 67 g, frappe pleine et charnue.', 'Benjolan taktil bulat 67 g, tekanan penuh dan berisi.'],
  'pack.ibm_model_m': ['屈曲弹簧，钢板回响的清亮敲击。', 'Buckling springs with a bright ring from the steel plate.', 'Muelles de pandeo con un eco brillante de la placa de acero.', 'Molas de flexão com um eco brilhante da placa de aço.', 'Изгибающиеся пружины и звонкое эхо стальной пластины.', 'バックリングスプリングと鋼板が響く明るい打鍵音。', 'Knickfedern mit hellem Nachklang der Stahlplatte.', 'Ressorts à flambage et écho clair de la plaque d’acier.', 'Pegas buckling dengan gema terang dari pelat baja.'],
  'pack.kailh_box_white': ['粗发声杆重段落，厚重响亮的咔嗒声。', 'Thick click bar and a heavy bump: a loud, weighty click.', 'Barra de clic gruesa y tope fuerte: un clic sonoro y pesado.', 'Barra de clique grossa e ressalto forte: um clique alto e pesado.', 'Толстая кликовая планка и сильный бугорок: громкий тяжёлый клик.', '太いクリックバーと重い段差、厚く大きなクリック音。', 'Dicker Klickbügel, kräftiger Druckpunkt: lauter, satter Klick.', 'Barre de clic épaisse et bosse marquée : clic fort et lourd.', 'Batang klik tebal dan benjolan berat: klik keras dan mantap.'],
  'pack.topre_electrostatic': ['软弹枕音，温润厚重的静电容手感。', 'Soft cushioned thock with a warm, deep capacitive feel.', 'Sonido acolchado y cálido, con tacto capacitivo profundo.', 'Som almofadado e quente, com toque capacitivo profundo.', 'Мягкий глухой звук, тёплое ёмкостное ощущение.', '柔らかく弾む打鍵音、温かく厚い静電容量の感触。', 'Weich gepolsterter Thock, warmes, tiefes kapazitives Gefühl.', 'Son feutré et chaud, toucher capacitif profond.', 'Bunyi empuk dan hangat dengan rasa kapasitif yang dalam.'],
  'pack.bubble_pop': ['水滴 Q 弹，清新活泼的气泡音。', 'Bouncy water drops: fresh, playful bubble pops.', 'Gotas de agua saltarinas: burbujas frescas y alegres.', 'Gotas de água saltitantes: bolhas frescas e alegres.', 'Упругие капли: свежие задорные пузырьки.', 'ぷるんと弾む水滴、爽やかで楽しい泡の音。', 'Springende Wassertropfen: frische, verspielte Blasen.', 'Gouttes rebondissantes : bulles fraîches et joyeuses.', 'Tetes air memantul: letupan gelembung segar dan ceria.'],
  'pack.scifi_laser': ['频率调制合成音，赛博感的镭射击发。', 'FM synth zaps with a cyberpunk laser feel.', 'Disparos de síntesis FM con aire láser cyberpunk.', 'Disparos de síntese FM com ar laser cyberpunk.', 'FM-синтез: киберпанковые лазерные выстрелы.', 'FM 合成のサイバーなレーザー音。', 'FM-Synth-Zaps mit Cyberpunk-Laser-Flair.', 'Tirs en synthèse FM façon laser cyberpunk.', 'Tembakan synth FM bernuansa laser cyberpunk.'],
  'pack.typewriter_1930s': ['与经典打字机同一台机器的另一组击键，节奏更轻快。', 'More strikes from the same machine as Typewriter, with a lighter rhythm.', 'Otros golpes de la misma máquina que Typewriter, con ritmo más ligero.', 'Outros golpes da mesma máquina do Typewriter, com ritmo mais leve.', 'Другие удары той же машинки, что и Typewriter, ритм легче.', '「Typewriter」と同じ機械の別の打鍵、軽快なリズム。', 'Weitere Anschläge derselben Maschine wie Typewriter, leichter im Rhythmus.', 'D’autres frappes de la même machine que Typewriter, rythme plus léger.', 'Ketukan lain dari mesin yang sama dengan Typewriter, ritme lebih ringan.'],
  'pack.silent_red': ['佳达隆墨轴线性轻压，顺滑清亮的敲击声。', 'Gateron Red Ink: light linear press, smooth and bright.', 'Gateron Red Ink: lineal ligero, suave y brillante.', 'Gateron Red Ink: linear leve, suave e brilhante.', 'Gateron Red Ink: лёгкий линейный ход, гладкий и звонкий.', 'Gateron 墨赤軸：軽いリニア、なめらかで明るい音。', 'Gateron Red Ink: leicht und linear, weich und hell.', 'Gateron Red Ink : linéaire léger, doux et clair.', 'Gateron Red Ink: linear ringan, halus dan terang.'],
  'pack.bubble': ['上升水音与回声，清澈的咕噜冒泡质感。', 'Rising water tones and echo, clear gurgling bubbles.', 'Tonos de agua ascendentes con eco, burbujeo claro.', 'Tons de água ascendentes com eco, borbulhar claro.', 'Восходящие водные тона с эхом, чистое бульканье.', '上昇する水音と残響、澄んだぽこぽこ泡音。', 'Aufsteigende Wassertöne mit Echo, klares Blubbern.', 'Notes d’eau montantes et écho, glouglou limpide.', 'Nada air naik dan gema, gelembung jernih.'],
  'pack.typewriter': ['击键闷响与字车铃声，怀旧打字机韵律。', 'Muffled strikes and the carriage bell: a nostalgic typewriter rhythm.', 'Golpes sordos y la campanilla del carro: ritmo de máquina de escribir clásico.', 'Golpes abafados e o sino do carro: ritmo nostálgico de máquina de escrever.', 'Глухие удары и звонок каретки: ностальгия пишущей машинки.', 'こもった打鍵とキャリッジのベル、懐かしいタイプライター。', 'Dumpfe Anschläge und Wagenglocke: nostalgischer Schreibmaschinen-Rhythmus.', 'Frappes sourdes et sonnette du chariot : rythme nostalgique.', 'Ketukan teredam dan bel kereta: ritme mesin tik nostalgia.'],
  'pack.mechanical': ['干脆利落的通用机械轴敲击声。', 'Crisp, all-round mechanical switch sound.', 'Sonido mecánico nítido y versátil.', 'Som mecânico nítido e versátil.', 'Чёткий универсальный механический звук.', '歯切れのよい定番のメカニカル音。', 'Knackiger, vielseitiger mechanischer Klang.', 'Son mécanique net et polyvalent.', 'Bunyi switch mekanis yang renyah dan serbaguna.'],
  'pack.sword': ['金属下滑音与泛音共鸣，利落出鞘声。', 'Sliding metal and ringing overtones: a sword leaving its sheath.', 'Metal deslizante y armónicos: una espada desenvainada.', 'Metal deslizante e harmónicos: uma espada a sair da bainha.', 'Скользящий металл и обертоны: меч из ножен.', '金属が滑る音と倍音、抜刀の響き。', 'Gleitendes Metall und Obertöne: ein gezogenes Schwert.', 'Métal qui glisse et harmoniques : une épée dégainée.', 'Logam meluncur dan gema nada: pedang keluar dari sarungnya.'],
  'pack.cherry_g80_3000': ['经典樱桃 G80 键盘实录，明亮清脆的敲击声。', 'Recorded from a classic Cherry G80: bright and crisp.', 'Grabado de un Cherry G80 clásico: brillante y nítido.', 'Gravado de um Cherry G80 clássico: brilhante e nítido.', 'Запись классической Cherry G80: звонко и чётко.', '定番 Cherry G80 の実録、明るく歯切れよい音。', 'Aufnahme einer klassischen Cherry G80: hell und knackig.', 'Enregistré sur un Cherry G80 classique : clair et net.', 'Rekaman Cherry G80 klasik: terang dan renyah.'],
  'pack.cherry_g80_3494': ['樱桃 G80 键盘实录，比 3000 更低沉短促。', 'Recorded from a Cherry G80: deeper and shorter than the 3000.', 'Grabado de un Cherry G80: más grave y corto que el 3000.', 'Gravado de um Cherry G80: mais grave e curto que o 3000.', 'Запись Cherry G80: ниже и короче, чем 3000.', 'Cherry G80 の実録、3000 より低く短い音。', 'Aufnahme einer Cherry G80: tiefer und kürzer als die 3000.', 'Enregistré sur un Cherry G80 : plus grave et court que le 3000.', 'Rekaman Cherry G80: lebih dalam dan singkat dari 3000.'],
  'pack.drum': ['下沉鼓声与鼓皮敲击，节拍感十足。', 'Falling drum tones and drumhead hits, full of groove.', 'Tambores que caen y golpes de parche, con mucho ritmo.', 'Tambores descendentes e batidas de pele, cheios de ritmo.', 'Нисходящие барабаны и удары по мембране, чистый ритм.', '沈み込むドラムと打面の音、ノリのいいビート。', 'Fallende Trommeln und Fellschläge, voller Groove.', 'Tambours descendants et frappes de peau, plein de groove.', 'Nada drum turun dan pukulan kulit drum, penuh irama.'],
  'pack.sandpaper': ['粗粝的沙沙摩擦声，颗粒感十足。', 'Rough, gritty sanding rasps.', 'Raspado áspero y granuloso.', 'Raspar áspero e granuloso.', 'Грубый зернистый шорох.', 'ざらざらと粒感のある擦れる音。', 'Rauer, körniger Schleifklang.', 'Frottement rugueux et granuleux.', 'Gesekan kasar dan berbutir.'],
  'pack.chalk': ['粉笔划过黑板的细碎刮擦声。', 'Chalk scratching across a blackboard.', 'Tiza raspando una pizarra.', 'Giz a riscar um quadro.', 'Мел, скребущий по доске.', 'チョークが黒板をこする細かな音。', 'Kreide, die über die Tafel kratzt.', 'Craie qui gratte un tableau noir.', 'Kapur menggores papan tulis.'],
  'pack.ipad_tap': ['手指轻敲玻璃屏幕的清脆点按声。', 'A fingertip tapping a glass screen.', 'Un dedo tocando una pantalla de cristal.', 'Um dedo a tocar num ecrã de vidro.', 'Пальцем по стеклянному экрану.', '指先でガラス画面を軽く叩く音。', 'Fingertipp auf einen Glasbildschirm.', 'Un doigt qui tapote un écran en verre.', 'Ujung jari mengetuk layar kaca.'],
  'pack.plastic_bag': ['塑料袋窸窣揉搓的皱褶声。', 'A crinkling, rustling plastic bag.', 'Una bolsa de plástico que cruje.', 'Um saco de plástico a amarrotar.', 'Шуршащий пластиковый пакет.', 'ビニール袋をくしゃくしゃ揉む音。', 'Eine knisternde Plastiktüte.', 'Un sac plastique qui froisse.', 'Kantong plastik yang berkeresek.'],
  'pack.straw_sip': ['吸管吮吸饮料的咕噜水声。', 'Slurping a drink through a straw.', 'Sorbiendo una bebida con pajita.', 'A sorver uma bebida por uma palhinha.', 'Пьём через трубочку.', 'ストローで飲み物をすする音。', 'Schlürfen durch einen Strohhalm.', 'On aspire une boisson à la paille.', 'Menyeruput minuman dengan sedotan.'],
}

LANGUAGE_NAMES = {
  'zh': '简体中文', 'en': 'English', 'es': 'Español', 'pt': 'Português',
  'ru': 'Русский', 'ja': '日本語', 'de': 'Deutsch', 'fr': 'Français', 'id': 'Bahasa Indonesia',
}


def main():
  import re
  out = {lang: {} for lang in LANGS}
  for key, values in S.items():
    assert len(values) == len(LANGS), f'{key}: {len(values)} values'
    want = sorted(re.findall(r'\{\w+\}', values[0]))
    for lang, text in zip(LANGS, values):
      assert sorted(re.findall(r'\{\w+\}', text)) == want, f'{key}/{lang} placeholders'
      out[lang][key] = text
  doc = {'languages': LANGS, 'names': LANGUAGE_NAMES, 'strings': out}
  path = Path(__file__).resolve().parent.parent / 'assets/i18n/strings.json'
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
  print(f'wrote {path} ({len(S)} keys x {len(LANGS)} languages)')


if __name__ == '__main__':
  main()
