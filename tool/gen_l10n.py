#!/usr/bin/env python3
"""Generates lib/l10n_strings.dart. Edit the table below, then run: python3 tool/gen_l10n.py
Order of columns: hi, bn, es, ar, ru.  {0},{1} are placeholders; keep technical terms (Tor, SOCKS5, DNS, IP) as is.
These are first-draft translations: a native speaker should review them before a stable release."""
import re, sys, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
LANGS = ['hi', 'bn', 'es', 'ar', 'ru']

main = open('lib/main.dart').read()
i = main.index("Route the whole computer through Tor?")
seg = main[i:main.index("actions:", i)]
m = re.search(r"Text\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)", seg[seg.index("When you connect"):] if False else seg[seg.index("Text(\n") if False else 0:])
body = None
for mm in re.finditer(r"Text\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)", seg):
    t = ''.join(re.findall(r"'((?:[^'\\]|\\.)*)'", mm.group(1)))
    if t.startswith('When you connect'):
        body = t.replace('\\n', '\n').replace("\\'", "'")
assert body, 'system-wide body not found'

T = [
 ("About OnionDesk", "OnionDesk के बारे में", "OnionDesk সম্পর্কে", "Acerca de OnionDesk", "حول OnionDesk", "О программе OnionDesk"),
 ("About", "जानकारी", "সম্পর্কে", "Acerca de", "حول", "О программе"),
 ("Locations", "स्थान", "অবস্থান", "Ubicaciones", "المواقع", "Расположения"),
 ("Language", "भाषा", "ভাষা", "Idioma", "اللغة", "Язык"),
 ("More", "और", "আরও", "Más", "المزيد", "Ещё"),
 ("Protected", "सुरक्षित", "সুরক্ষিত", "Protegido", "محمي", "Защищено"),
 ("Not protected", "सुरक्षित नहीं", "সুরক্ষিত নয়", "No protegido", "غير محمي", "Не защищено"),
 ("Pick a country and connect", "देश चुनें और कनेक्ट करें", "একটি দেশ বেছে সংযোগ করুন", "Elige un país y conéctate", "اختر دولة ثم اتصل", "Выберите страну и подключитесь"),
 ("Connect", "कनेक्ट करें", "সংযোগ করুন", "Conectar", "اتصال", "Подключить"),
 ("Connecting…", "कनेक्ट हो रहा है…", "সংযোগ হচ্ছে…", "Conectando…", "جارٍ الاتصال…", "Подключение…"),
 ("Disconnect", "डिस्कनेक्ट करें", "সংযোগ বিচ্ছিন্ন করুন", "Desconectar", "قطع الاتصال", "Отключить"),
 ("Starting Tor…", "Tor शुरू हो रहा है…", "Tor চালু হচ্ছে…", "Iniciando Tor…", "جارٍ تشغيل Tor…", "Запуск Tor…"),
 ("Building a Tor circuit · {0}%", "Tor सर्किट बन रहा है · {0}%", "Tor সার্কিট তৈরি হচ্ছে · {0}%", "Creando un circuito de Tor · {0}%", "جارٍ بناء دارة Tor · {0}%", "Построение цепочки Tor · {0}%"),
 ("Switching location — traffic stays inside Tor", "स्थान बदला जा रहा है — ट्रैफ़िक Tor के अंदर ही रहता है", "অবস্থান বদলানো হচ্ছে — ট্র্যাফিক Tor-এর ভেতরেই থাকে", "Cambiando de ubicación: el tráfico sigue dentro de Tor", "جارٍ تغيير الموقع — تبقى حركة المرور داخل Tor", "Смена расположения — трафик остаётся внутри Tor"),
 ("Exit in {0} · SOCKS5 {1}", "{0} में एग्ज़िट · SOCKS5 {1}", "{0}-এ এক্সিট · SOCKS5 {1}", "Salida en {0} · SOCKS5 {1}", "الخروج في {0} · SOCKS5 {1}", "Выход: {0} · SOCKS5 {1}"),
 ("Auto-fastest · Exit in {0} · SOCKS5 {1}", "स्वतः-सबसे तेज़ · {0} में एग्ज़िट · SOCKS5 {1}", "অটো-দ্রুততম · {0}-এ এক্সিট · SOCKS5 {1}", "Auto (más rápido) · Salida en {0} · SOCKS5 {1}", "الأسرع تلقائيًا · الخروج في {0} · SOCKS5 {1}", "Авто (самый быстрый) · Выход: {0} · SOCKS5 {1}"),
 ("System-wide: off · browser/proxy apps only", "सिस्टम-व्यापी: बंद · केवल ब्राउज़र/प्रॉक्सी ऐप", "সিস্টেম-ব্যাপী: বন্ধ · শুধু ব্রাউজার/প্রক্সি অ্যাপ", "Todo el sistema: desactivado · solo apps con proxy/navegador", "على مستوى النظام: متوقف · تطبيقات المتصفح/الوكيل فقط", "Весь компьютер: выкл. · только браузеры и приложения с прокси"),
 ("System-wide: on · all apps", "सिस्टम-व्यापी: चालू · सभी ऐप", "সিস্টেম-ব্যাপী: চালু · সব অ্যাপ", "Todo el sistema: activado · todas las apps", "على مستوى النظام: مفعّل · جميع التطبيقات", "Весь компьютер: вкл. · все приложения"),
 ("Ad blocker: off", "विज्ञापन ब्लॉकर: बंद", "বিজ্ঞাপন ব্লকার: বন্ধ", "Bloqueador de anuncios: desactivado", "حاجب الإعلانات: متوقف", "Блокировщик рекламы: выкл."),
 ("Ad blocker: on", "विज्ञापन ब्लॉकर: चालू", "বিজ্ঞাপন ব্লকার: চালু", "Bloqueador de anuncios: activado", "حاجب الإعلانات: مفعّل", "Блокировщик рекламы: вкл."),
 ("Ad blocker: on · {0} blocked", "विज्ञापन ब्लॉकर: चालू · {0} ब्लॉक", "বিজ্ঞাপন ব্লকার: চালু · {0} ব্লক", "Bloqueador de anuncios: activado · {0} bloqueados", "حاجب الإعلانات: مفعّل · {0} محظور", "Блокировщик рекламы: вкл. · заблокировано {0}"),
 ("Block known ad and tracker domains for apps using the proxy", "प्रॉक्सी इस्तेमाल करने वाले ऐप के लिए ज्ञात विज्ञापन और ट्रैकर डोमेन ब्लॉक करें", "প্রক্সি ব্যবহারকারী অ্যাপের জন্য পরিচিত বিজ্ঞাপন ও ট্র্যাকার ডোমেন ব্লক করুন", "Bloquea dominios de anuncios y rastreadores conocidos para las apps que usan el proxy", "حظر نطاقات الإعلانات والمتتبعات المعروفة للتطبيقات التي تستخدم الوكيل", "Блокировать известные рекламные и трекерные домены для приложений, использующих прокси"),
 ("Disconnect to change this", "इसे बदलने के लिए डिस्कनेक्ट करें", "এটি বদলাতে সংযোগ বিচ্ছিন্ন করুন", "Desconecta para cambiar esto", "اقطع الاتصال لتغيير هذا", "Отключитесь, чтобы изменить"),
 ("Not available in System-wide mode yet", "सिस्टम-व्यापी मोड में अभी उपलब्ध नहीं", "সিস্টেম-ব্যাপী মোডে এখনও উপলব্ধ নয়", "Aún no está disponible en el modo de todo el sistema", "غير متاح بعد في وضع النظام بأكمله", "Пока недоступно в режиме всего компьютера"),
 ("Send all apps' traffic through Tor (asks for administrator permission)", "सभी ऐप का ट्रैफ़िक Tor से भेजें (प्रशासक अनुमति माँगता है)", "সব অ্যাপের ট্র্যাফিক Tor দিয়ে পাঠান (প্রশাসকের অনুমতি চায়)", "Enviar el tráfico de todas las apps por Tor (pide permiso de administrador)", "إرسال حركة جميع التطبيقات عبر Tor (يطلب إذن المسؤول)", "Направлять трафик всех приложений через Tor (запросит права администратора)"),
 ("Fastest available", "सबसे तेज़ उपलब्ध", "সবচেয়ে দ্রুত উপলব্ধ", "El más rápido disponible", "الأسرع المتاح", "Самый быстрый доступный"),
 ("Search a country…", "देश खोजें…", "দেশ খুঁজুন…", "Buscar un país…", "ابحث عن دولة…", "Поиск страны…"),
 ("Automatically use the location with the highest speed", "सबसे अधिक गति वाले स्थान का अपने-आप उपयोग करें", "সর্বোচ্চ গতির অবস্থান স্বয়ংক্রিয়ভাবে ব্যবহার করুন", "Usar automáticamente la ubicación más rápida", "استخدام الموقع الأسرع تلقائيًا", "Автоматически использовать самое быстрое расположение"),
 ("Auto", "ऑटो", "অটো", "Auto", "تلقائي", "Авто"),
 ("REAL IP", "असली IP", "আসল IP", "IP REAL", "عنوان IP الحقيقي", "РЕАЛЬНЫЙ IP"),
 ("EXIT IP", "एग्ज़िट IP", "এক্সিট IP", "IP DE SALIDA", "عنوان IP للخروج", "IP ВЫХОДА"),
 ("SPEED", "गति", "গতি", "VELOCIDAD", "السرعة", "СКОРОСТЬ"),
 ("REAL", "असली", "আসল", "REAL", "الحقيقي", "РЕАЛЬНЫЙ"),
 ("EXIT", "एग्ज़िट", "এক্সিট", "SALIDA", "الخروج", "ВЫХОД"),
 ("guard", "गार्ड", "গার্ড", "guardia", "الحارس", "входной"),
 ("middle", "मध्य", "মধ্য", "intermedio", "الأوسط", "средний"),
 ("Bridges", "ब्रिज", "ব্রিজ", "Puentes", "الجسور", "Мосты"),
 ("Bridges: off", "ब्रिज: बंद", "ব্রিজ: বন্ধ", "Puentes: desactivados", "الجسور: متوقفة", "Мосты: выкл."),
 ("Connect through a bridge when Tor is blocked on your network", "जब आपके नेटवर्क पर Tor अवरुद्ध हो तो ब्रिज के ज़रिए कनेक्ट करें", "আপনার নেটওয়ার্কে Tor ব্লক থাকলে ব্রিজের মাধ্যমে সংযোগ করুন", "Conéctate mediante un puente cuando Tor esté bloqueado en tu red", "اتصل عبر جسر عندما يكون Tor محظورًا على شبكتك", "Подключайтесь через мост, если Tor заблокирован в вашей сети"),
 ("Bridges hide that you use Tor. Use one if your network blocks Tor. They are slower, and Snowflake needs the most patience.", "ब्रिज यह छिपाते हैं कि आप Tor इस्तेमाल करते हैं। अगर आपका नेटवर्क Tor रोकता है तो इस्तेमाल करें। ये धीमे होते हैं, और Snowflake में सबसे ज़्यादा धैर्य चाहिए।", "ব্রিজ লুকায় যে আপনি Tor ব্যবহার করছেন। আপনার নেটওয়ার্ক Tor আটকালে ব্যবহার করুন। এগুলো ধীর, আর Snowflake-এ সবচেয়ে বেশি ধৈর্য লাগে।", "Los puentes ocultan que usas Tor. Úsalos si tu red bloquea Tor. Son más lentos y Snowflake requiere más paciencia.", "تُخفي الجسور أنك تستخدم Tor. استخدمها إذا كانت شبكتك تحظر Tor. هي أبطأ، و Snowflake يتطلب أكبر قدر من الصبر.", "Мосты скрывают, что вы используете Tor. Применяйте их, если сеть блокирует Tor. Они медленнее, а Snowflake требует больше всего терпения."),
 ("Not available in this install: the bridge transports are not bundled.", "इस इंस्टॉल में उपलब्ध नहीं: ब्रिज ट्रांसपोर्ट साथ नहीं हैं।", "এই ইনস্টলে উপলব্ধ নয়: ব্রিজ ট্রান্সপোর্ট সাথে নেই।", "No disponible en esta instalación: los transportes de puentes no están incluidos.", "غير متاح في هذا التثبيت: وسائل نقل الجسور غير مضمّنة.", "Недоступно в этой установке: транспорты мостов не входят в комплект."),
 ("No bridge (direct to Tor)", "कोई ब्रिज नहीं (सीधे Tor)", "কোনো ব্রিজ নয় (সরাসরি Tor)", "Sin puente (directo a Tor)", "بدون جسر (مباشرة إلى Tor)", "Без моста (напрямую в Tor)"),
 ("obfs4 (built-in bridges)", "obfs4 (अंतर्निहित ब्रिज)", "obfs4 (বিল্ট-ইন ব্রিজ)", "obfs4 (puentes incluidos)", "obfs4 (جسور مدمجة)", "obfs4 (встроенные мосты)"),
 ("meek (looks like a CDN)", "meek (CDN जैसा दिखता है)", "meek (CDN-এর মতো দেখায়)", "meek (parece una CDN)", "meek (يبدو كشبكة CDN)", "meek (выглядит как CDN)"),
 ("My own bridges", "मेरे अपने ब्रिज", "আমার নিজের ব্রিজ", "Mis propios puentes", "جسوري الخاصة", "Мои собственные мосты"),
 ("One bridge per line, e.g. obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0", "हर पंक्ति में एक ब्रिज, जैसे obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0", "প্রতি লাইনে একটি ব্রিজ, যেমন obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0", "Un puente por línea, p. ej. obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0", "جسر واحد في كل سطر، مثل obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0", "Один мост на строку, например obfs4 1.2.3.4:443 FINGERPRINT cert=… iat-mode=0"),
 ("Get bridges at bridges.torproject.org. System-wide mode cannot be combined with bridges yet.", "ब्रिज bridges.torproject.org से लें। सिस्टम-व्यापी मोड अभी ब्रिज के साथ नहीं चल सकता।", "ব্রিজ bridges.torproject.org থেকে নিন। সিস্টেম-ব্যাপী মোড এখনও ব্রিজের সাথে চলে না।", "Obtén puentes en bridges.torproject.org. El modo de todo el sistema aún no se puede combinar con puentes.", "احصل على الجسور من bridges.torproject.org. لا يمكن دمج وضع النظام بأكمله مع الجسور بعد.", "Получите мосты на bridges.torproject.org. Режим всего компьютера пока нельзя сочетать с мостами."),
 ("Save", "सहेजें", "সংরক্ষণ", "Guardar", "حفظ", "Сохранить"),
 ("Disconnect to change this.", "इसे बदलने के लिए डिस्कनेक्ट करें।", "এটি বদলাতে সংযোগ বিচ্ছিন্ন করুন।", "Desconecta para cambiar esto.", "اقطع الاتصال لتغيير هذا.", "Отключитесь, чтобы изменить."),
 ("Bridges: {0}", "ब्रिज: {0}", "ব্রিজ: {0}", "Puentes: {0}", "الجسور: {0}", "Мосты: {0}"),
 ("Bridges cannot be combined with System-wide mode yet. Turn one of them off.", "ब्रिज को अभी सिस्टम-व्यापी मोड के साथ नहीं जोड़ा जा सकता। इनमें से एक बंद करें।", "ব্রিজ এখনও সিস্টেম-ব্যাপী মোডের সাথে চালানো যায় না। একটি বন্ধ করুন।", "Los puentes aún no se pueden combinar con el modo de todo el sistema. Desactiva uno de los dos.", "لا يمكن دمج الجسور مع وضع النظام بأكمله بعد. أوقف أحدهما.", "Мосты пока нельзя сочетать с режимом всего компьютера. Отключите что-то одно."),
 ("Installed apps", "इंस्टॉल किए गए ऐप", "ইনস্টল করা অ্যাপ", "Apps instaladas", "التطبيقات المثبّتة", "Установленные приложения"),
 ("Circuits ({0})", "सर्किट ({0})", "সার্কিট ({0})", "Circuitos ({0})", "الدارات ({0})", "Цепочки ({0})"),
 ("Countries only. Sites shown are visible on this computer only.", "केवल देश। दिखाई गई साइटें सिर्फ़ इसी कंप्यूटर पर दिखती हैं।", "শুধু দেশ। দেখানো সাইটগুলো কেবল এই কম্পিউটারেই দেখা যায়।", "Solo países. Los sitios mostrados solo se ven en este equipo.", "الدول فقط. المواقع المعروضة تظهر على هذا الحاسوب فقط.", "Только страны. Показанные сайты видны только на этом компьютере."),
 ("Split tunneling", "स्प्लिट टनलिंग", "স্প্লিট টানেলিং", "Túnel dividido", "النفق المقسّم", "Раздельное туннелирование"),
 ("Run chosen apps through Tor: pick from your installed apps", "चुने हुए ऐप Tor से चलाएँ: अपने इंस्टॉल किए ऐप में से चुनें", "বেছে নেওয়া অ্যাপ Tor দিয়ে চালান: ইনস্টল করা অ্যাপ থেকে বাছুন", "Ejecuta las apps elegidas por Tor: elige entre tus apps instaladas", "شغّل التطبيقات المختارة عبر Tor: اختر من تطبيقاتك المثبّتة", "Запускайте выбранные приложения через Tor: выберите из установленных"),
 ("Settings", "सेटिंग", "সেটিংস", "Ajustes", "الإعدادات", "Настройки"),
 ("General", "सामान्य", "সাধারণ", "General", "عام", "Общие"),
 ("Connection", "कनेक्शन", "সংযোগ", "Conexión", "الاتصال", "Подключение"),
 ("Privacy & blocking", "गोपनीयता और ब्लॉकिंग", "গোপনীয়তা ও ব্লকিং", "Privacidad y bloqueo", "الخصوصية والحظر", "Конфиденциальность и блокировка"),
 ("Auto-rotate", "ऑटो-रोटेट", "অটো-রোটেট", "Rotación automática", "التدوير التلقائي", "Автосмена"),
 ("Ad blocker", "विज्ञापन ब्लॉकर", "বিজ্ঞাপন ব্লকার", "Bloqueador de anuncios", "حاجب الإعلانات", "Блокировщик рекламы"),
 ("Opens minimised. It does not connect unless you also turn on the next option.", "छोटी विंडो में खुलता है। अगला विकल्प चालू किए बिना यह कनेक्ट नहीं करता।", "মিনিমাইজ অবস্থায় খোলে। পরের বিকল্প চালু না করলে সংযোগ করে না।", "Se abre minimizado. No se conecta salvo que actives también la siguiente opción.", "يُفتح مصغّرًا. لا يتصل ما لم تفعّل الخيار التالي أيضًا.", "Открывается свёрнутым. Не подключается, пока вы не включите следующий пункт."),
 ("Connects with your last location as soon as the app is up.", "ऐप चालू होते ही आपके पिछले स्थान से कनेक्ट करता है।", "অ্যাপ চালু হলেই আপনার শেষ অবস্থান দিয়ে সংযোগ করে।", "Se conecta con tu última ubicación en cuanto la app está lista.", "يتصل بموقعك الأخير فور تشغيل التطبيق.", "Подключается к последнему расположению сразу после запуска."),
 ("Asks GitHub for the latest release now and then. Nothing is installed automatically.", "समय-समय पर GitHub से नवीनतम रिलीज़ पूछता है। कुछ भी अपने-आप इंस्टॉल नहीं होता।", "মাঝে মাঝে GitHub-এ সর্বশেষ রিলিজ জানতে চায়। কিছুই স্বয়ংক্রিয়ভাবে ইনস্টল হয় না।", "Consulta a GitHub de vez en cuando la última versión. No se instala nada automáticamente.", "يسأل GitHub بين حين وآخر عن أحدث إصدار. لا يُثبَّت شيء تلقائيًا.", "Время от времени спрашивает GitHub о последнем выпуске. Ничего не устанавливается автоматически."),
 ("Check", "जाँचें", "দেখুন", "Comprobar", "تحقق", "Проверить"),
 ("Version {0}", "संस्करण {0}", "সংস্করণ {0}", "Versión {0}", "الإصدار {0}", "Версия {0}"),
 ("Switch to a fresh relay in the same country on a timer.", "टाइमर पर उसी देश में नया रिले अपनाएँ।", "টাইমার অনুযায়ী একই দেশে নতুন রিলেতে যান।", "Cambia a un relé nuevo del mismo país con un temporizador.", "انتقل إلى مرحّل جديد في البلد نفسه وفق مؤقّت.", "По таймеру переключаться на новый узел в той же стране."),
 ("Use a bridge when your network blocks Tor.", "जब आपका नेटवर्क Tor रोके तो ब्रिज इस्तेमाल करें।", "আপনার নেটওয়ার্ক Tor ব্লক করলে ব্রিজ ব্যবহার করুন।", "Usa un puente cuando tu red bloquea Tor.", "استخدم جسرًا عندما تحظر شبكتك Tor.", "Используйте мост, если сеть блокирует Tor."),
 ("Auto never uses them and they cannot be selected.", "ऑटो उन्हें कभी इस्तेमाल नहीं करता और उन्हें चुना नहीं जा सकता।", "অটো এগুলো কখনও ব্যবহার করে না এবং এগুলো বেছে নেওয়া যায় না।", "Auto nunca los usa y no se pueden seleccionar.", "لا يستخدمها الوضع التلقائي ولا يمكن اختيارها.", "Авто их не использует, и выбрать их нельзя."),
 ("None", "कोई नहीं", "কোনোটি নয়", "Ninguno", "لا شيء", "Нет"),
 ("About 72,000 domains. Applies on the next connect.", "लगभग 72,000 डोमेन। अगले कनेक्ट पर लागू होता है।", "প্রায় ৭২,০০০ ডোমেন। পরের সংযোগে প্রযোজ্য হয়।", "Unos 72 000 dominios. Se aplica en la próxima conexión.", "نحو 72,000 نطاق. يُطبَّق عند الاتصال التالي.", "Около 72 000 доменов. Применяется при следующем подключении."),
 ("Downloading…", "डाउनलोड हो रहा है…", "ডাউনলোড হচ্ছে…", "Descargando…", "جارٍ التنزيل…", "Загрузка…"),
 ("Not downloaded yet (about 72,000 domains)", "अभी डाउनलोड नहीं हुआ (लगभग 72,000 डोमेन)", "এখনও ডাউনলোড হয়নি (প্রায় ৭২,০০০ ডোমেন)", "Aún no descargada (unos 72 000 dominios)", "لم تُنزَّل بعد (نحو 72,000 نطاق)", "Ещё не загружен (около 72 000 доменов)"),
 ("Downloaded: {0} domains · {1}", "डाउनलोड हुआ: {0} डोमेन · {1}", "ডাউনলোড হয়েছে: {0} ডোমেন · {1}", "Descargada: {0} dominios · {1}", "تم التنزيل: {0} نطاق · {1}", "Загружено: {0} доменов · {1}"),
 ("Updated: {0} domains (applies on the next connect)", "अपडेट हुआ: {0} डोमेन (अगले कनेक्ट पर लागू)", "আপডেট হয়েছে: {0} ডোমেন (পরের সংযোগে প্রযোজ্য)", "Actualizada: {0} dominios (se aplica en la próxima conexión)", "تم التحديث: {0} نطاق (يُطبَّق عند الاتصال التالي)", "Обновлено: {0} доменов (применится при следующем подключении)"),
 ("Could not download the list: {0}", "सूची डाउनलोड नहीं हो सकी: {0}", "তালিকা ডাউনলোড করা যায়নি: {0}", "No se pudo descargar la lista: {0}", "تعذّر تنزيل القائمة: {0}", "Не удалось загрузить список: {0}"),
 ("Tools", "उपकरण", "টুলস", "Herramientas", "الأدوات", "Инструменты"),
 ("Run", "चलाएँ", "চালান", "Ejecutar", "تشغيل", "Запустить"),
 ("Choose app…", "ऐप चुनें…", "অ্যাপ বাছুন…", "Elegir app…", "اختر تطبيقًا…", "Выбрать приложение…"),
 ("Remove", "हटाएँ", "সরান", "Quitar", "إزالة", "Удалить"),
 ("Removed. The built-in list stays (applies on the next connect).", "हटा दिया गया। अंतर्निहित सूची बनी रहती है (अगले कनेक्ट पर लागू)।", "সরানো হয়েছে। বিল্ট-ইন তালিকা থাকে (পরের সংযোগে প্রযোজ্য)।", "Quitada. La lista integrada se mantiene (se aplica en la próxima conexión).", "تمت الإزالة. تبقى القائمة المضمّنة (يُطبَّق عند الاتصال التالي).", "Удалено. Встроенный список остаётся (применится при следующем подключении)."),
 ("Expand the map", "नक्शा बड़ा करें", "মানচিত্র বড় করুন", "Ampliar el mapa", "تكبير الخريطة", "Развернуть карту"),
 ("Restore the map (Esc)", "नक्शा सामान्य करें (Esc)", "মানচিত্র আগের অবস্থায় আনুন (Esc)", "Restaurar el mapa (Esc)", "استعادة الخريطة (Esc)", "Свернуть карту (Esc)"),
 ("Could not remove the list: {0}", "सूची हटाई नहीं जा सकी: {0}", "তালিকা সরানো যায়নি: {0}", "No se pudo quitar la lista: {0}", "تعذّرت إزالة القائمة: {0}", "Не удалось удалить список: {0}"),
 ("Zoom in", "ज़ूम इन करें", "জুম ইন করুন", "Acercar", "تكبير", "Приблизить"),
 ("Zoom out", "ज़ूम आउट करें", "জুম আউট করুন", "Alejar", "تصغير", "Отдалить"),
 ("Reset view", "दृश्य रीसेट करें", "ভিউ রিসেট করুন", "Restablecer vista", "إعادة ضبط العرض", "Сбросить вид"),
 ("Reaching the Tor network…", "Tor नेटवर्क तक पहुँच रहा है…", "Tor নেটওয়ার্কে পৌঁছানো হচ্ছে…", "Conectando con la red Tor…", "جارٍ الوصول إلى شبكة Tor…", "Подключение к сети Tor…"),
 ("Downloading the network directory…", "नेटवर्क डायरेक्टरी डाउनलोड हो रही है…", "নেটওয়ার্ক ডিরেক্টরি ডাউনলোড হচ্ছে…", "Descargando el directorio de la red…", "جارٍ تنزيل دليل الشبكة…", "Загрузка каталога сети…"),
 ("Fetching relay information…", "रिले की जानकारी ली जा रही है…", "রিলের তথ্য আনা হচ্ছে…", "Obteniendo información de los relés…", "جارٍ جلب معلومات المرحّلات…", "Получение сведений об узлах…"),
 ("Building your circuit…", "आपका सर्किट बन रहा है…", "আপনার সার্কিট তৈরি হচ্ছে…", "Creando tu circuito…", "جارٍ بناء دارتك…", "Построение вашей цепочки…"),
 ("Real IP", "असली IP", "আসল IP", "IP real", "عنوان IP الحقيقي", "Реальный IP"),
 ("Exit IP", "एग्ज़िट IP", "এক্সিট IP", "IP de salida", "عنوان IP للخروج", "IP выхода"),
 ("Real", "असली", "আসল", "Real", "الحقيقي", "Реальный"),
 ("Exit", "एग्ज़िट", "এক্সিট", "Salida", "الخروج", "Выход"),
 ("Refresh", "रीफ़्रेश", "রিফ্রেশ", "Actualizar", "تحديث", "Обновить"),
 ("Checking", "जाँच हो रही है", "যাচাই হচ্ছে", "Comprobando", "جارٍ الفحص", "Проверка"),
 ("testing…", "परीक्षण हो रहा है…", "পরীক্ষা চলছে…", "probando…", "جارٍ الاختبار…", "тест…"),
 ("loading…", "लोड हो रहा है…", "লোড হচ্ছে…", "cargando…", "جارٍ التحميل…", "загрузка…"),
 ("direct", "सीधा", "সরাসরি", "directo", "مباشر", "напрямую"),
 ("via OnionDesk", "OnionDesk के ज़रिए", "OnionDesk-এর মাধ্যমে", "mediante OnionDesk", "عبر OnionDesk", "через OnionDesk"),
 ("live est. · {0}s ago", "लाइव अनुमान · {0} से पहले", "লাইভ অনুমান · {0}সে আগে", "estimación en vivo · hace {0}s", "تقدير مباشر · قبل {0} ث", "оценка · {0} с назад"),
 ("New identity", "नई पहचान", "নতুন পরিচয়", "Nueva identidad", "هوية جديدة", "Новая личность"),
 ("Get a new exit relay automatically", "नया एग्ज़िट रिले अपने-आप पाएँ", "স্বয়ংক্রিয়ভাবে নতুন এক্সিট রিলে পান", "Obtener un nuevo relé de salida automáticamente", "الحصول على مرحّل خروج جديد تلقائيًا", "Автоматически получать новый выходной узел"),
 ("Use a different relay in {0} and move open connections to it", "{0} में दूसरा रिले इस्तेमाल करें और खुले कनेक्शन उस पर ले जाएँ", "{0}-এ অন্য রিলে ব্যবহার করুন এবং খোলা সংযোগগুলো সেখানে সরান", "Usar otro relé en {0} y mover las conexiones abiertas a él", "استخدام مرحّل مختلف في {0} ونقل الاتصالات المفتوحة إليه", "Использовать другой узел в {0} и перенести на него открытые соединения"),
 ("Connect first", "पहले कनेक्ट करें", "আগে সংযোগ করুন", "Conéctate primero", "اتصل أولًا", "Сначала подключитесь"),
 ("Auto-rotate: off", "ऑटो-रोटेट: बंद", "অটো-রোটেট: বন্ধ", "Rotación automática: desactivada", "التدوير التلقائي: متوقف", "Автосмена: выкл."),
 ("Rotate every {0} min", "हर {0} मिनट में बदलें", "প্রতি {0} মিনিটে বদলান", "Rotar cada {0} min", "تدوير كل {0} دقيقة", "Менять каждые {0} мин"),
 ("Every {0} min", "हर {0} मिनट", "প্রতি {0} মিনিট", "Cada {0} min", "كل {0} دقيقة", "Каждые {0} мин"),
 ("Off", "बंद", "বন্ধ", "Desactivado", "متوقف", "Выкл."),
 ("Leak test", "लीक परीक्षण", "লিক পরীক্ষা", "Prueba de fugas", "اختبار التسرب", "Проверка утечек"),
 ("Check that your real IP and DNS do not leak", "जाँचें कि आपका असली IP और DNS लीक नहीं हो रहे", "যাচাই করুন আপনার আসল IP ও DNS ফাঁস হচ্ছে না", "Comprueba que tu IP real y el DNS no se filtran", "تحقق من عدم تسرب عنوان IP الحقيقي وDNS", "Проверьте, что реальный IP и DNS не утекают"),
 ("Exclude countries", "देश बाहर रखें", "দেশ বাদ দিন", "Excluir países", "استبعاد دول", "Исключить страны"),
 ("Excluding {0}", "{0} बाहर", "{0}টি বাদ", "Excluyendo {0}", "استبعاد {0}", "Исключено: {0}"),
 ("Countries Auto never uses and that cannot be selected", "ऐसे देश जिन्हें ऑटो कभी नहीं चुनता और जिन्हें चुना नहीं जा सकता", "যেসব দেশ অটো কখনও ব্যবহার করে না এবং বেছে নেওয়া যায় না", "Países que Auto nunca usa y que no se pueden seleccionar", "دول لا يستخدمها الوضع التلقائي ولا يمكن اختيارها", "Страны, которые Авто никогда не использует и которые нельзя выбрать"),
 ("Excluded countries are never used as an exit: Auto skips them and they cannot be selected.", "बाहर रखे गए देश कभी एग्ज़िट के रूप में इस्तेमाल नहीं होते: ऑटो उन्हें छोड़ देता है और उन्हें चुना नहीं जा सकता।", "বাদ দেওয়া দেশ কখনও এক্সিট হিসেবে ব্যবহার হয় না: অটো সেগুলো এড়িয়ে যায় এবং সেগুলো বেছে নেওয়া যায় না।", "Los países excluidos nunca se usan como salida: Auto los omite y no se pueden seleccionar.", "لا تُستخدم الدول المستبعدة كنقطة خروج: يتجاوزها الوضع التلقائي ولا يمكن اختيارها.", "Исключённые страны никогда не используются как выход: Авто их пропускает, и выбрать их нельзя."),
 ("{0} (current location)", "{0} (वर्तमान स्थान)", "{0} (বর্তমান অবস্থান)", "{0} (ubicación actual)", "{0} (الموقع الحالي)", "{0} (текущее расположение)"),
 ("Five Eyes", "फ़ाइव आइज़", "ফাইভ আইজ", "Cinco Ojos", "العيون الخمس", "«Пять глаз»"),
 ("Nine Eyes", "नाइन आइज़", "নাইন আইজ", "Nueve Ojos", "العيون التسع", "«Девять глаз»"),
 ("Fourteen Eyes", "फ़ोर्टीन आइज़", "ফোর্টিন আইজ", "Catorce Ojos", "العيون الأربع عشرة", "«Четырнадцать глаз»"),
 ("Clear", "साफ़ करें", "পরিষ্কার করুন", "Borrar", "مسح", "Очистить"),
 ("Cancel", "रद्द करें", "বাতিল", "Cancelar", "إلغاء", "Отмена"),
 ("Save ({0})", "सहेजें ({0})", "সংরক্ষণ ({0})", "Guardar ({0})", "حفظ ({0})", "Сохранить ({0})"),
 ("Search", "खोजें", "খুঁজুন", "Buscar", "بحث", "Поиск"),
 ("Close", "बंद करें", "বন্ধ করুন", "Cerrar", "إغلاق", "Закрыть"),
 ("Download", "डाउनलोड", "ডাউনলোড", "Descargar", "تنزيل", "Скачать"),
 ("Dismiss", "हटाएँ", "সরান", "Descartar", "تجاهل", "Скрыть"),
 ("OnionDesk {0} is available (you have {1}).", "OnionDesk {0} उपलब्ध है (आपके पास {1} है)।", "OnionDesk {0} উপলব্ধ (আপনার কাছে {1} আছে)।", "OnionDesk {0} está disponible (tienes {1}).", "OnionDesk {0} متاح (لديك {1}).", "Доступна версия OnionDesk {0} (у вас {1})."),
 ("Check for updates automatically", "अपडेट अपने-आप जाँचें", "স্বয়ংক্রিয়ভাবে আপডেট দেখুন", "Buscar actualizaciones automáticamente", "التحقق من التحديثات تلقائيًا", "Автоматически проверять обновления"),
 ("Check for updates now", "अभी अपडेट जाँचें", "এখনই আপডেট দেখুন", "Buscar actualizaciones ahora", "التحقق من التحديثات الآن", "Проверить обновления сейчас"),
 ("Run an app through OnionDesk…", "OnionDesk के ज़रिए ऐप चलाएँ…", "OnionDesk-এর মাধ্যমে অ্যাপ চালান…", "Ejecutar una app a través de OnionDesk…", "تشغيل تطبيق عبر OnionDesk…", "Запустить приложение через OnionDesk…"),
 ("Start OnionDesk when I log in", "लॉगिन पर OnionDesk शुरू करें", "লগইনের সময় OnionDesk চালু করুন", "Iniciar OnionDesk al iniciar sesión", "تشغيل OnionDesk عند تسجيل الدخول", "Запускать OnionDesk при входе"),
 ("Connect automatically on launch", "शुरू होते ही अपने-आप कनेक्ट करें", "চালু হলে স্বয়ংক্রিয়ভাবে সংযোগ করুন", "Conectar automáticamente al iniciar", "الاتصال تلقائيًا عند التشغيل", "Подключаться автоматически при запуске"),
 ("Download the full ad-block list (StevenBlack, MIT)", "पूरी विज्ञापन-ब्लॉक सूची डाउनलोड करें (StevenBlack, MIT)", "পূর্ণ বিজ্ঞাপন-ব্লক তালিকা ডাউনলোড করুন (StevenBlack, MIT)", "Descargar la lista completa de bloqueo de anuncios (StevenBlack, MIT)", "تنزيل قائمة حظر الإعلانات الكاملة (StevenBlack، MIT)", "Скачать полный список блокировки рекламы (StevenBlack, MIT)"),
 ("Run an app through OnionDesk", "OnionDesk के ज़रिए ऐप चलाएँ", "OnionDesk-এর মাধ্যমে অ্যাপ চালান", "Ejecutar una app a través de OnionDesk", "تشغيل تطبيق عبر OnionDesk", "Запуск приложения через OnionDesk"),
 ("Starts the program with OnionDesk's proxy (127.0.0.1:9050) set, so only that app goes through Tor. Browsers get their own private profile with remote DNS and WebRTC off.", "प्रोग्राम को OnionDesk के प्रॉक्सी (127.0.0.1:9050) के साथ शुरू करता है, ताकि केवल वही ऐप Tor से जाए। ब्राउज़र को रिमोट DNS और बंद WebRTC वाली अपनी निजी प्रोफ़ाइल मिलती है।", "প্রোগ্রামটি OnionDesk-এর প্রক্সি (127.0.0.1:9050) সহ চালু করে, যাতে শুধু সেই অ্যাপ Tor দিয়ে যায়। ব্রাউজার রিমোট DNS ও বন্ধ WebRTC সহ নিজস্ব ব্যক্তিগত প্রোফাইল পায়।", "Inicia el programa con el proxy de OnionDesk (127.0.0.1:9050), de modo que solo esa app pasa por Tor. Los navegadores reciben su propio perfil privado con DNS remoto y WebRTC desactivado.", "يشغّل البرنامج مع وكيل OnionDesk (127.0.0.1:9050) بحيث يمر ذلك التطبيق وحده عبر Tor. تحصل المتصفحات على ملف تعريف خاص بها مع DNS عن بُعد وتعطيل WebRTC.", "Запускает программу с прокси OnionDesk (127.0.0.1:9050), поэтому через Tor идёт только это приложение. Браузеры получают отдельный профиль с удалённым DNS и отключённым WebRTC."),
 ("Recent", "हाल के", "সাম্প্রতিক", "Recientes", "الأحدث", "Недавние"),
 ("Apps that ignore proxy settings are not covered (install torsocks, or use System-wide mode).", "प्रॉक्सी सेटिंग अनदेखी करने वाले ऐप शामिल नहीं हैं (torsocks इंस्टॉल करें या सिस्टम-व्यापी मोड इस्तेमाल करें)।", "প্রক্সি সেটিং উপেক্ষা করা অ্যাপ অন্তর্ভুক্ত নয় (torsocks ইনস্টল করুন বা সিস্টেম-ব্যাপী মোড ব্যবহার করুন)।", "Las apps que ignoran la configuración de proxy no quedan cubiertas (instala torsocks o usa el modo de todo el sistema).", "التطبيقات التي تتجاهل إعدادات الوكيل غير مشمولة (ثبّت torsocks أو استخدم وضع النظام بأكمله).", "Приложения, игнорирующие настройки прокси, не защищены (установите torsocks или используйте режим всего компьютера)."),
 ("Run", "चलाएँ", "চালান", "Ejecutar", "تشغيل", "Запустить"),
 ("firefox   or   /path/to/app --option", "firefox   या   /path/to/app --option", "firefox   বা   /path/to/app --option", "firefox   o   /ruta/a/app --opción", "firefox   أو   /path/to/app --option", "firefox   или   /path/to/app --option"),
 ("Leak test", "लीक परीक्षण", "লিক পরীক্ষা", "Prueba de fugas", "اختبار التسرب", "Проверка утечек"),
 ("Traffic through the proxy", "प्रॉक्सी से गुज़रता ट्रैफ़िक", "প্রক্সির মধ্য দিয়ে ট্র্যাফিক", "Tráfico a través del proxy", "الحركة عبر الوكيل", "Трафик через прокси"),
 ("Sites see {0} (a Tor exit), not your real IP.", "साइटें {0} (एक Tor एग्ज़िट) देखती हैं, आपका असली IP नहीं।", "সাইটগুলো {0} (একটি Tor এক্সিট) দেখে, আপনার আসল IP নয়।", "Los sitios ven {0} (una salida de Tor), no tu IP real.", "ترى المواقع {0} (مخرج Tor) وليس عنوان IP الحقيقي.", "Сайты видят {0} (выход Tor), а не ваш реальный IP."),
 ("Sites see {0}, not your real IP.", "साइटें {0} देखती हैं, आपका असली IP नहीं।", "সাইটগুলো {0} দেখে, আপনার আসল IP নয়।", "Los sitios ven {0}, no tu IP real.", "ترى المواقع {0} وليس عنوان IP الحقيقي.", "Сайты видят {0}, а не ваш реальный IP."),
 ("Sites see your real IP ({0}).", "साइटें आपका असली IP ({0}) देखती हैं।", "সাইটগুলো আপনার আসল IP ({0}) দেখে।", "Los sitios ven tu IP real ({0}).", "ترى المواقع عنوان IP الحقيقي ({0}).", "Сайты видят ваш реальный IP ({0})."),
 ("{0} is not a known Tor exit.", "{0} ज्ञात Tor एग्ज़िट नहीं है।", "{0} পরিচিত Tor এক্সিট নয়।", "{0} no es una salida de Tor conocida.", "{0} ليس مخرج Tor معروفًا.", "{0} не является известным выходом Tor."),
 ("No answer through the proxy. Is OnionDesk connected?", "प्रॉक्सी से कोई उत्तर नहीं मिला। क्या OnionDesk कनेक्ट है?", "প্রক্সি থেকে কোনো উত্তর নেই। OnionDesk কি সংযুক্ত?", "Sin respuesta a través del proxy. ¿Está conectado OnionDesk?", "لا إجابة عبر الوكيل. هل OnionDesk متصل؟", "Нет ответа через прокси. OnionDesk подключён?"),
 ("DNS lookups", "DNS खोज", "DNS অনুসন্ধান", "Consultas DNS", "استعلامات DNS", "DNS-запросы"),
 ("Names are resolved inside Tor for apps that use the proxy (SOCKS5 with remote DNS).", "प्रॉक्सी इस्तेमाल करने वाले ऐप के नाम Tor के अंदर हल होते हैं (रिमोट DNS वाला SOCKS5)।", "প্রক্সি ব্যবহারকারী অ্যাপের নাম Tor-এর ভেতরে সমাধান হয় (রিমোট DNS সহ SOCKS5)।", "Los nombres se resuelven dentro de Tor para las apps que usan el proxy (SOCKS5 con DNS remoto).", "تُحلّ الأسماء داخل Tor للتطبيقات التي تستخدم الوكيل (SOCKS5 مع DNS عن بُعد).", "Для приложений, использующих прокси, имена разрешаются внутри Tor (SOCKS5 с удалённым DNS)."),
 ("A hostname could not be resolved through Tor.", "Tor के ज़रिए होस्टनेम हल नहीं हो सका।", "Tor-এর মাধ্যমে হোস্টনেম সমাধান করা যায়নি।", "No se pudo resolver un nombre de host a través de Tor.", "تعذّر حلّ اسم مضيف عبر Tor.", "Не удалось разрешить имя хоста через Tor."),
 ("Could not test.", "परीक्षण नहीं हो सका।", "পরীক্ষা করা যায়নি।", "No se pudo probar.", "تعذّر الاختبار.", "Не удалось проверить."),
 ("Apps that ignore the proxy", "प्रॉक्सी अनदेखा करने वाले ऐप", "প্রক্সি উপেক্ষাকারী অ্যাপ", "Apps que ignoran el proxy", "التطبيقات التي تتجاهل الوكيل", "Приложения, игнорирующие прокси"),
 ("Normal for proxy mode: only apps that use the proxy are protected. Turn on System-wide mode (Linux) to cover every app.", "प्रॉक्सी मोड में सामान्य: केवल प्रॉक्सी इस्तेमाल करने वाले ऐप सुरक्षित हैं। हर ऐप के लिए सिस्टम-व्यापी मोड (Linux) चालू करें।", "প্রক্সি মোডে স্বাভাবিক: শুধু প্রক্সি ব্যবহারকারী অ্যাপ সুরক্ষিত। সব অ্যাপের জন্য সিস্টেম-ব্যাপী মোড (Linux) চালু করুন।", "Normal en el modo proxy: solo están protegidas las apps que usan el proxy. Activa el modo de todo el sistema (Linux) para cubrir todas las apps.", "أمر طبيعي في وضع الوكيل: التطبيقات التي تستخدم الوكيل وحدها محمية. فعّل وضع النظام بأكمله (Linux) لتغطية كل التطبيقات.", "Для режима прокси это нормально: защищены только приложения, использующие прокси. Включите режим всего компьютера (Linux), чтобы охватить все приложения."),
 ("System-wide mode: even a plain connection leaves through Tor ({0}).", "सिस्टम-व्यापी मोड: साधारण कनेक्शन भी Tor से निकलता है ({0})।", "সিস্টেম-ব্যাপী মোড: সাধারণ সংযোগও Tor দিয়ে বেরোয় ({0})।", "Modo de todo el sistema: incluso una conexión normal sale por Tor ({0}).", "وضع النظام بأكمله: حتى الاتصال العادي يخرج عبر Tor ({0}).", "Режим всего компьютера: даже обычное соединение выходит через Tor ({0})."),
 ("System-wide mode is on but a plain connection shows your real IP ({0}).", "सिस्टम-व्यापी मोड चालू है पर साधारण कनेक्शन आपका असली IP ({0}) दिखाता है।", "সিস্টেম-ব্যাপী মোড চালু কিন্তু সাধারণ সংযোগ আপনার আসল IP ({0}) দেখায়।", "El modo de todo el sistema está activado, pero una conexión normal muestra tu IP real ({0}).", "وضع النظام بأكمله مفعّل لكن الاتصال العادي يُظهر عنوان IP الحقيقي ({0}).", "Режим всего компьютера включён, но обычное соединение показывает ваш реальный IP ({0})."),
 ("A plain connection does not show your real IP.", "साधारण कनेक्शन आपका असली IP नहीं दिखाता।", "সাধারণ সংযোগ আপনার আসল IP দেখায় না।", "Una conexión normal no muestra tu IP real.", "الاتصال العادي لا يُظهر عنوان IP الحقيقي.", "Обычное соединение не показывает ваш реальный IP."),
 ("WebRTC (browser)", "WebRTC (ब्राउज़र)", "WebRTC (ব্রাউজার)", "WebRTC (navegador)", "WebRTC (المتصفح)", "WebRTC (браузер)"),
 ("Cannot be tested here. In Firefox set media.peerconnection.enabled to false; in Chrome use a WebRTC-blocking extension.", "यहाँ परीक्षण संभव नहीं। Firefox में media.peerconnection.enabled को false करें; Chrome में WebRTC रोकने वाला एक्सटेंशन इस्तेमाल करें।", "এখানে পরীক্ষা করা সম্ভব নয়। Firefox-এ media.peerconnection.enabled false করুন; Chrome-এ WebRTC-ব্লকিং এক্সটেনশন ব্যবহার করুন।", "No se puede probar aquí. En Firefox pon media.peerconnection.enabled en false; en Chrome usa una extensión que bloquee WebRTC.", "لا يمكن اختباره هنا. في Firefox اضبط media.peerconnection.enabled على false؛ وفي Chrome استخدم إضافة تحظر WebRTC.", "Здесь это проверить нельзя. В Firefox установите media.peerconnection.enabled в false; в Chrome используйте расширение, блокирующее WebRTC."),
 ("Recovered from an unclean exit: your previous proxy settings were restored.", "अनुचित रूप से बंद होने से उबरा: आपकी पिछली प्रॉक्सी सेटिंग बहाल कर दी गई।", "অস্বাভাবিক বন্ধ থেকে পুনরুদ্ধার: আপনার আগের প্রক্সি সেটিং ফিরিয়ে আনা হয়েছে।", "Recuperado tras un cierre inesperado: se restauró tu configuración de proxy anterior.", "تمت الاستعادة بعد إغلاق غير سليم: أُعيدت إعدادات الوكيل السابقة.", "Восстановление после некорректного завершения: прежние настройки прокси возвращены."),
 ("Recovered from an unclean exit: your previous network settings were restored.", "अनुचित रूप से बंद होने से उबरा: आपकी पिछली नेटवर्क सेटिंग बहाल कर दी गई।", "অস্বাভাবিক বন্ধ থেকে পুনরুদ্ধার: আপনার আগের নেটওয়ার্ক সেটিং ফিরিয়ে আনা হয়েছে।", "Recuperado tras un cierre inesperado: se restauró tu configuración de red anterior.", "تمت الاستعادة بعد إغلاق غير سليم: أُعيدت إعدادات الشبكة السابقة.", "Восстановление после некорректного завершения: прежние сетевые настройки возвращены."),
 ("The last session did not exit cleanly and some settings could not be restored. Run  oniondesk-restore  in a terminal.", "पिछला सत्र ठीक से बंद नहीं हुआ और कुछ सेटिंग बहाल नहीं हो सकीं। टर्मिनल में  oniondesk-restore  चलाएँ।", "আগের সেশন ঠিকভাবে বন্ধ হয়নি এবং কিছু সেটিং ফেরানো যায়নি। টার্মিনালে  oniondesk-restore  চালান।", "La última sesión no terminó correctamente y algunos ajustes no se pudieron restaurar. Ejecuta  oniondesk-restore  en una terminal.", "لم تنتهِ الجلسة الأخيرة بشكل سليم وتعذّرت استعادة بعض الإعدادات. شغّل  oniondesk-restore  في الطرفية.", "Прошлый сеанс завершился некорректно, часть настроек не удалось восстановить. Выполните  oniondesk-restore  в терминале."),
 ("Internet is blocked: a previous system-wide session ended unexpectedly. Restore normal networking, or connect again.", "इंटरनेट अवरुद्ध है: पिछला सिस्टम-व्यापी सत्र अचानक समाप्त हो गया। सामान्य नेटवर्किंग बहाल करें या फिर से कनेक्ट करें।", "ইন্টারনেট ব্লক: আগের সিস্টেম-ব্যাপী সেশন হঠাৎ শেষ হয়েছে। স্বাভাবিক নেটওয়ার্কিং ফিরিয়ে আনুন বা আবার সংযোগ করুন।", "Internet bloqueado: una sesión anterior de todo el sistema terminó inesperadamente. Restaura la red normal o conéctate de nuevo.", "الإنترنت محظور: انتهت جلسة النظام بأكمله السابقة بشكل غير متوقع. استعد الشبكة العادية أو اتصل مجددًا.", "Интернет заблокирован: предыдущий сеанс режима всего компьютера завершился неожиданно. Восстановите обычную сеть или подключитесь снова."),
 ("Restore", "बहाल करें", "পুনরুদ্ধার", "Restaurar", "استعادة", "Восстановить"),
 ("System-wide mode unavailable", "सिस्टम-व्यापी मोड उपलब्ध नहीं", "সিস্টেম-ব্যাপী মোড অনুপলব্ধ", "Modo de todo el sistema no disponible", "وضع النظام بأكمله غير متاح", "Режим всего компьютера недоступен"),
 ("Route the whole computer through Tor?", "पूरे कंप्यूटर को Tor से गुज़ारें?", "পুরো কম্পিউটারকে Tor দিয়ে চালাবেন?", "¿Enrutar todo el equipo a través de Tor?", "توجيه الحاسوب بأكمله عبر Tor؟", "Направить весь компьютер через Tor?"),
 ("@SYSWIDE_BODY@", "जब आप कनेक्ट करेंगे, OnionDesk एक बार आपका प्रशासक पासवर्ड माँगेगा, फिर हर ऐप का सारा TCP ट्रैफ़िक और DNS Tor से भेजेगा, किसी भी डेस्कटॉप (GNOME, KDE, …) पर।\n\n• Tor UDP नहीं ले जा सकता, इसलिए कनेक्ट रहते QUIC/HTTP3, गेम और वॉइस कॉल बंद रहते हैं (ब्राउज़र HTTPS पर लौट जाते हैं)।\n• IPv6 बंद रहता है; स्थानीय नेटवर्क पते (192.168.x.x आदि) सीधे रहते हैं।\n• अगर Tor क्रैश हो जाए, तो आपके Restore दबाने तक ट्रैफ़िक बंद रहता है, ताकि कुछ लीक न हो।\n• डिस्कनेक्ट करने या ऐप बंद करने पर सामान्य नेटवर्किंग बहाल हो जाती है।", "আপনি সংযোগ করলে OnionDesk একবার আপনার প্রশাসক পাসওয়ার্ড চাইবে, তারপর প্রতিটি অ্যাপের সব TCP ট্র্যাফিক ও DNS Tor দিয়ে পাঠাবে, যেকোনো ডেস্কটপে (GNOME, KDE, …)।\n\n• Tor UDP বহন করতে পারে না, তাই সংযুক্ত থাকাকালীন QUIC/HTTP3, গেম ও ভয়েস কল বন্ধ থাকে (ব্রাউজার HTTPS-এ ফিরে যায়)।\n• IPv6 বন্ধ থাকে; স্থানীয় নেটওয়ার্ক ঠিকানা (192.168.x.x ইত্যাদি) সরাসরি থাকে।\n• Tor ক্র্যাশ করলে আপনি Restore চাপা পর্যন্ত ট্র্যাফিক বন্ধ থাকে, যাতে কিছু ফাঁস না হয়।\n• সংযোগ বিচ্ছিন্ন করলে বা অ্যাপ বন্ধ করলে স্বাভাবিক নেটওয়ার্কিং ফিরে আসে।", "Al conectar, OnionDesk pedirá una vez tu contraseña de administrador y luego enviará todo el tráfico TCP y el DNS de cada app a través de Tor, en cualquier escritorio (GNOME, KDE, …).\n\n• Tor no transporta UDP, así que QUIC/HTTP3, los juegos y las llamadas de voz se bloquean mientras estás conectado (los navegadores recurren a HTTPS).\n• IPv6 se bloquea; las direcciones de la red local (192.168.x.x, etc.) siguen siendo directas.\n• Si Tor se cae, el tráfico sigue bloqueado hasta que pulses Restaurar, para que no se filtre nada.\n• Al desconectar o cerrar la app se restaura la red normal.", "عند الاتصال، سيطلب OnionDesk كلمة مرور المسؤول مرة واحدة، ثم يرسل كل حركة TCP وDNS من كل تطبيق عبر Tor، على أي سطح مكتب (GNOME وKDE …).\n\n• لا يستطيع Tor نقل UDP، لذا تُحظر QUIC/HTTP3 والألعاب والمكالمات الصوتية أثناء الاتصال (تعود المتصفحات إلى HTTPS).\n• يُحظر IPv6؛ وتبقى عناوين الشبكة المحلية (192.168.x.x وغيرها) مباشرة.\n• إذا تعطّل Tor تبقى الحركة محظورة حتى تضغط «استعادة» فلا يتسرب شيء.\n• يؤدي قطع الاتصال أو إغلاق التطبيق إلى استعادة الشبكة العادية.", "При подключении OnionDesk один раз запросит пароль администратора, затем направит весь TCP-трафик и DNS каждого приложения через Tor — в любом окружении (GNOME, KDE, …).\n\n• Tor не передаёт UDP, поэтому пока вы подключены, QUIC/HTTP3, игры и голосовые звонки блокируются (браузеры переходят на HTTPS).\n• IPv6 блокируется; адреса локальной сети (192.168.x.x и т. д.) остаются прямыми.\n• Если Tor аварийно завершится, трафик остаётся заблокированным, пока вы не нажмёте «Восстановить», чтобы ничего не утекло.\n• При отключении или закрытии приложения обычная сеть восстанавливается."),
 ("Enable", "चालू करें", "চালু করুন", "Activar", "تفعيل", "Включить"),
 ("Could not restore", "बहाल नहीं हो सका", "পুনরুদ্ধার করা যায়নি", "No se pudo restaurar", "تعذّرت الاستعادة", "Не удалось восстановить"),
 ("Uninstall OnionDesk?", "OnionDesk अनइंस्टॉल करें?", "OnionDesk আনইনস্টল করবেন?", "¿Desinstalar OnionDesk?", "إلغاء تثبيت OnionDesk؟", "Удалить OnionDesk?"),
 ("This will completely remove OnionDesk from this computer:", "यह OnionDesk को इस कंप्यूटर से पूरी तरह हटा देगा:", "এটি এই কম্পিউটার থেকে OnionDesk সম্পূর্ণ সরিয়ে দেবে:", "Esto eliminará OnionDesk por completo de este equipo:", "سيؤدي هذا إلى إزالة OnionDesk بالكامل من هذا الحاسوب:", "OnionDesk будет полностью удалён с этого компьютера:"),
 ("Preview mode: nothing will actually be removed.", "पूर्वावलोकन मोड: असल में कुछ नहीं हटेगा।", "প্রিভিউ মোড: আসলে কিছুই সরানো হবে না।", "Modo de vista previa: no se eliminará nada realmente.", "وضع المعاينة: لن يُزال أي شيء فعليًا.", "Режим предпросмотра: на самом деле ничего не будет удалено."),
 ("Also delete my settings and saved data", "मेरी सेटिंग और सहेजा डेटा भी हटाएँ", "আমার সেটিং ও সংরক্ষিত ডেটাও মুছুন", "Eliminar también mis ajustes y datos guardados", "احذف أيضًا إعداداتي وبياناتي المحفوظة", "Также удалить мои настройки и сохранённые данные"),
 ("Preview", "पूर्वावलोकन", "প্রিভিউ", "Vista previa", "معاينة", "Предпросмотр"),
 ("Uninstall", "अनइंस्टॉल करें", "আনইনস্টল করুন", "Desinstalar", "إلغاء التثبيت", "Удалить"),
 ("Something went wrong.", "कुछ गड़बड़ हो गई।", "কিছু একটা সমস্যা হয়েছে।", "Algo salió mal.", "حدث خطأ ما.", "Что-то пошло не так."),
 ("Uninstalling OnionDesk", "OnionDesk अनइंस्टॉल हो रहा है", "OnionDesk আনইনস্টল হচ্ছে", "Desinstalando OnionDesk", "جارٍ إلغاء تثبيت OnionDesk", "Удаление OnionDesk"),
 ("Preview finished", "पूर्वावलोकन पूरा हुआ", "প্রিভিউ শেষ", "Vista previa terminada", "انتهت المعاينة", "Предпросмотр завершён"),
 ("OnionDesk has been uninstalled", "OnionDesk अनइंस्टॉल हो गया", "OnionDesk আনইনস্টল হয়েছে", "OnionDesk se ha desinstalado", "تم إلغاء تثبيت OnionDesk", "OnionDesk удалён"),
 ("Uninstall cancelled", "अनइंस्टॉल रद्द हुआ", "আনইনস্টল বাতিল", "Desinstalación cancelada", "أُلغي إلغاء التثبيت", "Удаление отменено"),
 ("Uninstall stopped", "अनइंस्टॉल रुक गया", "আনইনস্টল থেমে গেছে", "Desinstalación detenida", "توقف إلغاء التثبيت", "Удаление остановлено"),
 ("Getting ready…", "तैयारी हो रही है…", "প্রস্তুতি চলছে…", "Preparando…", "جارٍ التحضير…", "Подготовка…"),
 ("Nothing was removed. This was only a preview.", "कुछ नहीं हटाया गया। यह केवल पूर्वावलोकन था।", "কিছুই সরানো হয়নি। এটি কেবল প্রিভিউ ছিল।", "No se eliminó nada. Fue solo una vista previa.", "لم يُزل شيء. كانت معاينة فقط.", "Ничего не удалено. Это был только предпросмотр."),
 ("Everything was removed from this computer. Thank you for trying it.", "इस कंप्यूटर से सब कुछ हटा दिया गया। इसे आज़माने के लिए धन्यवाद।", "এই কম্পিউটার থেকে সবকিছু সরানো হয়েছে। চেষ্টা করার জন্য ধন্যবাদ।", "Se eliminó todo de este equipo. Gracias por probarlo.", "أُزيل كل شيء من هذا الحاسوب. شكرًا لتجربتك.", "Всё удалено с этого компьютера. Спасибо, что попробовали."),
 ("Please keep this window open.", "कृपया यह विंडो खुली रखें।", "অনুগ্রহ করে এই উইন্ডো খোলা রাখুন।", "Mantén esta ventana abierta.", "يرجى إبقاء هذه النافذة مفتوحة.", "Пожалуйста, не закрывайте это окно."),
 ("Back to OnionDesk", "OnionDesk पर लौटें", "OnionDesk-এ ফিরে যান", "Volver a OnionDesk", "العودة إلى OnionDesk", "Вернуться в OnionDesk"),
 ("Closing in {0}…", "{0} में बंद हो रहा है…", "{0}-এ বন্ধ হচ্ছে…", "Cerrando en {0}…", "الإغلاق خلال {0}…", "Закрытие через {0}…"),
 ("Try again", "फिर कोशिश करें", "আবার চেষ্টা করুন", "Intentar de nuevo", "حاول مرة أخرى", "Повторить"),
 ("Disconnecting and restoring your network", "डिस्कनेक्ट कर नेटवर्क बहाल किया जा रहा है", "সংযোগ বিচ্ছিন্ন করে নেটওয়ার্ক ফেরানো হচ্ছে", "Desconectando y restaurando tu red", "جارٍ قطع الاتصال واستعادة شبكتك", "Отключение и восстановление сети"),
 ("Deleting your settings and saved data", "आपकी सेटिंग और सहेजा डेटा हटाया जा रहा है", "আপনার সেটিং ও সংরক্ষিত ডেটা মোছা হচ্ছে", "Eliminando tus ajustes y datos guardados", "جارٍ حذف إعداداتك وبياناتك المحفوظة", "Удаление настроек и сохранённых данных"),
 ("Removing application files", "ऐप की फ़ाइलें हटाई जा रही हैं", "অ্যাপের ফাইল সরানো হচ্ছে", "Eliminando los archivos de la aplicación", "جارٍ إزالة ملفات التطبيق", "Удаление файлов приложения"),
 ("Removing firewall rules", "फ़ायरवॉल नियम हटाए जा रहे हैं", "ফায়ারওয়াল নিয়ম সরানো হচ্ছে", "Eliminando las reglas del cortafuegos", "جارٍ إزالة قواعد جدار الحماية", "Удаление правил брандмауэра"),
 ("Removing system helper and data", "सिस्टम सहायक और डेटा हटाया जा रहा है", "সিস্টেম সহায়ক ও ডেটা সরানো হচ্ছে", "Eliminando el asistente del sistema y sus datos", "جارٍ إزالة مساعد النظام وبياناته", "Удаление системного помощника и данных"),
 ("OnionDesk, its Start menu and desktop shortcuts, and the bundled Tor", "OnionDesk, उसके स्टार्ट मेन्यू और डेस्कटॉप शॉर्टकट, और साथ आया Tor", "OnionDesk, এর স্টার্ট মেনু ও ডেস্কটপ শর্টকাট এবং সাথে থাকা Tor", "OnionDesk, sus accesos del menú Inicio y del escritorio, y el Tor incluido", "OnionDesk واختصارات قائمة ابدأ وسطح المكتب وTor المضمّن", "OnionDesk, его ярлыки в меню «Пуск» и на рабочем столе и встроенный Tor"),
 ("Your settings and saved data (%APPDATA%\\oniondesk)", "आपकी सेटिंग और सहेजा डेटा (%APPDATA%\\oniondesk)", "আপনার সেটিং ও সংরক্ষিত ডেটা (%APPDATA%\\oniondesk)", "Tus ajustes y datos guardados (%APPDATA%\\oniondesk)", "إعداداتك وبياناتك المحفوظة (%APPDATA%\\oniondesk)", "Ваши настройки и сохранённые данные (%APPDATA%\\oniondesk)"),
 ("OnionDesk and its menu entry (administrator permission is asked once)", "OnionDesk और उसकी मेन्यू प्रविष्टि (प्रशासक अनुमति एक बार माँगी जाती है)", "OnionDesk ও এর মেনু এন্ট্রি (প্রশাসকের অনুমতি একবার চাওয়া হয়)", "OnionDesk y su entrada de menú (se pide permiso de administrador una vez)", "OnionDesk وإدخال القائمة الخاص به (يُطلب إذن المسؤول مرة واحدة)", "OnionDesk и его пункт меню (права администратора запрашиваются один раз)"),
 ("The system-wide helper, its firewall table and the \"oniondesk\" system user", "सिस्टम-व्यापी सहायक, उसकी फ़ायरवॉल तालिका और \"oniondesk\" सिस्टम उपयोगकर्ता", "সিস্টেম-ব্যাপী সহায়ক, এর ফায়ারওয়াল টেবিল এবং \"oniondesk\" সিস্টেম ব্যবহারকারী", "El asistente de todo el sistema, su tabla del cortafuegos y el usuario del sistema \"oniondesk\"", "مساعد النظام بأكمله وجدول جدار الحماية الخاص به ومستخدم النظام \"oniondesk\"", "Системный помощник, его таблица брандмауэра и системный пользователь «oniondesk»"),
 ("The developer install in ~/.local/share/oniondesk and its menu entry", "~/.local/share/oniondesk में डेवलपर इंस्टॉल और उसकी मेन्यू प्रविष्टि", "~/.local/share/oniondesk-এ ডেভেলপার ইনস্টল ও এর মেনু এন্ট্রি", "La instalación de desarrollo en ~/.local/share/oniondesk y su entrada de menú", "تثبيت المطوّر في ~/.local/share/oniondesk وإدخال القائمة الخاص به", "Установка разработчика в ~/.local/share/oniondesk и её пункт меню"),
 ("Your settings and saved data (~/.config/oniondesk)", "आपकी सेटिंग और सहेजा डेटा (~/.config/oniondesk)", "আপনার সেটিং ও সংরক্ষিত ডেটা (~/.config/oniondesk)", "Tus ajustes y datos guardados (~/.config/oniondesk)", "إعداداتك وبياناتك المحفوظة (~/.config/oniondesk)", "Ваши настройки и сохранённые данные (~/.config/oniondesk)"),
 ("Tor Browser and any other Tor installs on this computer are never touched.", "Tor Browser और इस कंप्यूटर पर कोई भी अन्य Tor इंस्टॉल कभी नहीं छेड़ा जाता।", "Tor Browser এবং এই কম্পিউটারের অন্য কোনো Tor ইনস্টল কখনও ছোঁয়া হয় না।", "Tor Browser y cualquier otra instalación de Tor de este equipo nunca se tocan.", "لا يُمَسّ Tor Browser ولا أي تثبيت Tor آخر على هذا الحاسوب أبدًا.", "Tor Browser и другие установки Tor на этом компьютере никогда не затрагиваются."),
 ("The folder this copy runs from is not deleted. Other Tor installs and Tor Browser are never touched.", "जिस फ़ोल्डर से यह प्रति चल रही है वह नहीं हटाया जाता। अन्य Tor इंस्टॉल और Tor Browser कभी नहीं छेड़े जाते।", "যে ফোল্ডার থেকে এই কপি চলছে তা মোছা হয় না। অন্য Tor ইনস্টল ও Tor Browser কখনও ছোঁয়া হয় না।", "La carpeta desde la que se ejecuta esta copia no se elimina. Otras instalaciones de Tor y Tor Browser nunca se tocan.", "لا يُحذف المجلد الذي تعمل منه هذه النسخة. ولا تُمَسّ تثبيتات Tor الأخرى ولا Tor Browser أبدًا.", "Папка, из которой запущена эта копия, не удаляется. Другие установки Tor и Tor Browser никогда не затрагиваются."),
 ("Your previous proxy settings are put back first. Tor Browser and any other Tor installs are never touched. The app closes, then Windows removes its files in a few seconds.", "पहले आपकी पिछली प्रॉक्सी सेटिंग वापस रखी जाती है। Tor Browser और अन्य Tor इंस्टॉल कभी नहीं छेड़े जाते। ऐप बंद होता है, फिर Windows कुछ सेकंड में उसकी फ़ाइलें हटा देता है।", "প্রথমে আপনার আগের প্রক্সি সেটিং ফিরিয়ে দেওয়া হয়। Tor Browser ও অন্য Tor ইনস্টল কখনও ছোঁয়া হয় না। অ্যাপ বন্ধ হয়, তারপর Windows কয়েক সেকেন্ডে এর ফাইল সরিয়ে দেয়।", "Primero se restauran tus ajustes de proxy anteriores. Tor Browser y cualquier otra instalación de Tor nunca se tocan. La app se cierra y Windows elimina sus archivos en unos segundos.", "تُعاد أولًا إعدادات الوكيل السابقة. لا يُمَسّ Tor Browser ولا أي تثبيت Tor آخر. يُغلق التطبيق ثم يزيل Windows ملفاته خلال ثوانٍ.", "Сначала возвращаются прежние настройки прокси. Tor Browser и другие установки Tor никогда не затрагиваются. Приложение закроется, и через несколько секунд Windows удалит его файлы."),
]

def esc(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"

seen = set()
out = ["// GENERATED by tool/gen_l10n.py - edit the table there, not this file.\n",
       "// First-draft translations: a native speaker should review them before a stable release.\n",
       "const Map<String, Map<String, String>> kTranslations = {\n"]
rows = []
for row in T:
    assert len(row) == 6, row[0]
    key = body if row[0] == '@SYSWIDE_BODY@' else row[0]
    if key in seen: continue
    seen.add(key)
    rows.append((key, row[1:]))
for li, lang in enumerate(LANGS):
    out.append(f"  '{lang}': {{\n")
    for key, tr in rows:
        out.append(f"    {esc(key)}: {esc(tr[li])},\n")
    out.append("  },\n")
out.append("};\n")
open('lib/l10n_strings.dart', 'w').write(''.join(out))

# verify every plain key (no placeholder) appears in source or is a known dynamic string
src = ''.join(open(p).read() for p in ['lib/main.dart', 'lib/tools_ui.dart', 'lib/leak_test.dart', 'lib/uninstall.dart', 'lib/uninstall_page.dart'])
src_u = src.replace("\\'", "'").replace('\\\\', '\\')
bad = []
for key, _ in rows:
    probe = key.split('{0}')[0].split('{1}')[0]
    first = probe.split('\n')[0]
    if first and first not in src_u and first.replace('\\', '\\\\') not in src:
        bad.append(key[:70])
print(len(rows), 'strings x', len(LANGS), 'languages written;', len(bad), 'keys not found in source:')
for b in bad: print('  ', b)
