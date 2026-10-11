<p align="center"><img src="assets/icon-256.png" width="96" alt="הפוך שפה"></p>

<h1 align="center">הפוך שפה (hafuch-safa)</h1>

<p align="center">הקלדתם בשפה הלא נכונה? לחיצה אחת, והטקסט מתהפך לשפה הנכונה.</p>

---

כלי קטן שמתקן טקסט שהוקלד בפריסת מקלדת לא נכונה, ועובד ב-**Windows** וב-**macOS**. הקלדתם `akuo` כשהתכוונתם ל"שלום", או `יקךךם` כשהתכוונתם ל-`hello`? לוחצים <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd> (במק: <kbd>Ctrl</kbd>+<kbd>Option</kbd>+<kbd>L</kbd>), הטקסט מתהפך, ופריסת המקלדת של המערכת עוברת לשפה הנכונה כדי שתמשיכו להקליד בלי לעצור.

- **Windows:** ההוראות מיד למטה, מ[דרישות](#דרישות) ועד [מבנה הפרויקט](#מבנה-הפרויקט).
- **macOS:** התקנה בשורה אחת ושאר הפרטים ב[פרק macOS](#macos).

| מה שהוקלד | אחרי הקיצור |
|---|---|
| `akuo nv bang` | שלום מה נשמע |
| `יקךךם 'םרךג` | hello world |
| `akuo' nv bang?` | שלום, מה נשמע? |
| `גםמ,א` | don't |
| `tr.` | ארץ |

## איך זה עובד

- **יש טקסט מסומן:** רק הסימון מתהפך.
- **אין סימון:** המילה האחרונה שהקלדתם לפני הסמן מתהפכת.
- **לחיצות חוזרות:** כל לחיצה נוספת תוך 2 שניות מרחיבה את ההיפוך במילה אחת אחורה. שלוש לחיצות על `akuo nv bang` נותנות "שלום מה נשמע".
- **כיוון אוטומטי:** אם רוב האותיות באנגלית, הטקסט נהפך לעברית. אם רוב האותיות בעברית, הוא נהפך לאנגלית. ספרות, רווחים וסימנים שזהים בשתי הפריסות נשארים כמו שהם.
- **החלפת פריסה:** אחרי ההיפוך המערכת עוברת לפריסה של השפה החדשה (ב-Windows פריסת המקלדת, במק מקור הקלט).
- **חזרה:** טעיתם? לחיצה על אותה מילה אחרי יותר מ-2 שניות מחזירה אותה בדיוק כפי שהייתה, כולל אותיות גדולות.
- **הלוח (clipboard):** טקסט מסומן נקרא דרך הלוח, ומה שהיה בלוח לפני כן חוזר למקומו מיד. מה שהכלי עצמו שם בלוח לא נאסף להיסטוריית הלוח של Windows (Win+V), ובמק הוא מסומן כזמני כדי שמנהלי לוח יתעלמו ממנו.

הכלי עובד בכל תוכנה שמקבלת הקלדה: דפדפנים, WhatsApp, Outlook ו-Gmail, Slack, Word, פנקס רשימות וטרמינלים.

## דרישות

- Windows 10 או Windows 11.
- פריסת מקלדת עברית ופריסת מקלדת אנגלית מותקנות (הגדרות > זמן ושפה > שפה ואזור).
- [AutoHotkey v2](https://www.autohotkey.com). אם הוא חסר, ההתקנה מתקינה אותו לבד, למשתמש הנוכחי בלבד ובלי הרשאות מנהל: דרך winget, ואם winget חסר או ישן מדי, דרך הגרסה הניידת הרשמית מ-GitHub (עם בדיקת SHA256).

## התקנה

### בשורה אחת

מעתיקים את השורה הזו ומדביקים בטרמינל (cmd, PowerShell או Windows Terminal), או בחלון "הפעלה" (<kbd>Win</kbd>+<kbd>R</kbd>), ולוחצים Enter:

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.ps1 | iex"
```

השורה מורידה את הפרויקט לתיקייה זמנית, מריצה את ההתקנה ומוחקת את התיקייה הזמנית. אין צורך בהרשאות מנהל.

### או ידנית

1. מורידים את הפרויקט: בעמוד הזה ב-GitHub לוחצים על **Code** ואז **Download ZIP** וחולצים את הקובץ, או מריצים `git clone https://github.com/adiramsalem101/hafuch-safa.git`.
2. לוחצים לחיצה כפולה על `install.cmd`.

או מ-PowerShell, מתוך תיקיית הפרויקט:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

מה ההתקנה עושה:

- מתקינה AutoHotkey v2 אם הוא חסר (winget ברמת המשתמש, ואם זה לא מצליח, הגרסה הניידת הרשמית בתוך תיקיית הכלי).
- מעתיקה את הכלי אל `%LOCALAPPDATA%\hafuch-safa`. אחרי ההתקנה אפשר למחוק את התיקייה שהורדתם.
- מוסיפה קיצור דרך לתיקיית ההפעלה (Startup), כך שהכלי עולה בכל כניסה ל-Windows.
- מפעילה את הכלי. ליד השעון יופיע אייקון כחול עם א ו-A.

לא נדרשות הרשאות מנהל, ולא נדרש שום אישור ידני.

## שימוש

1. הקלדתם משהו בשפה הלא נכונה? לוחצים <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd>. המילה האחרונה מתהפכת והפריסה מתחלפת.
2. צריך להפוך עוד מילים אחורה? לוחצים שוב, מהר (עד 2 שניות בין לחיצה ללחיצה). כל לחיצה מוסיפה מילה.
3. רוצים להפוך קטע מסוים? מסמנים אותו ולוחצים.

תפריט האייקון ליד השעון (קליק ימני): השהיה, פתיחת קובץ ההגדרות, טעינה מחדש ויציאה.

## שינוי הקיצור וההגדרות

כל ההגדרות נמצאות בקובץ אחד: `%LOCALAPPDATA%\hafuch-safa\config.ini`. הדרך הקלה להגיע אליו: קליק ימני על האייקון ואז "פתח את קובץ ההגדרות".

כדי להחליף את הקיצור, משנים את השורה:

```ini
Hotkey=Ctrl+Alt+L
```

למשל ל-`Hotkey=Ctrl+Shift+K`, שומרים, ובוחרים "טען מחדש" בתפריט האייקון. אפשר לכתוב את הקיצור בצורה חופשית (`Ctrl+Alt+L`, `Win+Alt+H`, `Ctrl+Alt+F9`) או בתחביר של AutoHotkey (`^!l`). חובה לפחות מקש צירוף אחד.

| הגדרה | ברירת מחדל | מה היא עושה |
|---|---|---|
| `Hotkey` | `Ctrl+Alt+L` | שילוב המקשים |
| `HebrewLayout` | `auto` | `auto` קורא את הפריסות המותקנות, `standard` היא הטבלה של Hebrew (Standard) של Windows, `mac` היא פריסת Hebrew של macOS |
| `SwitchLayout` | `1` | להחליף את פריסת המקלדת אחרי ההיפוך |
| `ExpandWindowMs` | `2000` | כמה זמן לחיצה נוספת מרחיבה את ההיפוך |
| `InsertMethod` | `type` | `type` מקליד את הטקסט המתוקן, `paste` מדביק אותו דרך הלוח |
| `TerminalInsertMethod` | `type` | אותו דבר בטרמינלים |
| `ShowTips` | `1` | הודעה קטנה כשאין מה להפוך |
| `ExcludeApps` | ריק | תוכנות שבהן הקיצור לא יופעל, מופרדות בפסיק (למשל `idea64.exe`) |
| `DebugLog` | `0` | יומן אבחון. נרשמים בו רק אורכים ותוצאות, לעולם לא הטקסט |

## התנגשויות ידועות עם Ctrl+Alt+L

- **פריסת Hebrew (Standard):** Ctrl+Alt הוא AltGr, ו-AltGr+L מקליד את המירכאה `”`. כשהכלי פועל, הצירוף הופך טקסט במקום זה.
- **Word:** Ctrl+Alt+L מוסיף שדה LISTNUM.
- **IntelliJ, PyCharm ושאר סביבות JetBrains:** Ctrl+Alt+L מסדר קוד. אפשר להוסיף אותן ל-`ExcludeApps` או לבחור קיצור אחר.

## macOS

### דרישות

- macOS 13 ומעלה, כי Hammerspoon 1.1.1 לא נפתח בגרסאות ישנות יותר. ההתקנה בודקת את זה ואומרת. נבדק ב-macOS 15.7.
- מקור קלט עברי ומקור קלט אנגלי מוגדרים (הגדרות המערכת > מקלדת > מקורות קלט). כל אחד מ-Hebrew, Hebrew-PC או Hebrew-QWERTY מתאים, ובצד האנגלי ABC או U.S. אם אין מקור קלט עברי, ההתקנה אומרת איך להוסיף אותו.
- [Hammerspoon](https://www.hammerspoon.org), כלי אוטומציה חינמי בקוד פתוח שהכלי רץ בתוכו. אם הוא חסר, ההתקנה מתקינה אותו לבד מדף ה-Releases הרשמי ב-GitHub אל `~/Applications`: גרסה קבועה שנבדקה (1.1.1), עם בדיקת SHA256 ובדיקת חתימה של צוות Hammerspoon. לא דרך Homebrew, כי אז macOS עוצר את ההפעלה הראשונה בחלון אישור שההתקנה לא רואה.

### התקנה בשורה אחת

פותחים את Terminal (<kbd>Cmd</kbd>+<kbd>Space</kbd>, כותבים Terminal ולוחצים Enter), מדביקים את השורה הזו ולוחצים Enter:

```
curl -fsSL https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.sh | bash
```

השורה מורידה את הפרויקט לתיקייה זמנית, מריצה את `mac/install.sh` ומוחקת את התיקייה הזמנית. אין צורך בסיסמת מנהל.

או ידנית, מתוך תיקיית הפרויקט: `bash mac/install.sh`.

מה ההתקנה עושה:

- מתקינה Hammerspoon אם הוא חסר (בלי Homebrew ובלי סיסמת מנהל).
- מעתיקה את הכלי אל `~/.hammerspoon/hafuch-safa`. התקנה חוזרת (שדרוג) שומרת את קובץ ההגדרות הקיים.
- מוסיפה שורה אחת לסוף `~/.hammerspoon/init.lua`, ורק אם היא עוד לא שם. שאר הקובץ לא משתנה, כך שהגדרות Hammerspoon קיימות ממשיכות לעבוד.
- מפעילה את Hammerspoon בכניסה למחשב.
- אם Control ו-Command מוחלפים אצלכם, מגדירה את הקיצור כך שהמקשים Control+Option+L יעבדו (פרטים ב[מה שונה במק](#מה-שונה-במק)).
- מפעילה את Hammerspoon. בשורת התפריטים יופיע הסמל אA.

### הרשאת נגישות (פעם אחת)

macOS מאפשר לתוכנה לקרוא הקלדה ולשלוח הקשות רק אחרי אישור מפורש שלכם. בהפעלה הראשונה macOS שואל על Hammerspoon: לוחצים "פתח את הגדרות המערכת" (Open System Settings). ההתקנה גם פותחת בעצמה את **הגדרות המערכת > פרטיות ואבטחה > נגישות**: מפעילים את המתג ליד **Hammerspoon** (ייתכן שתתבקשו לאשר עם סיסמה או Touch ID). חלון ההגדרות של Hammerspoon עצמו, שנפתח באותו זמן, אפשר לסגור.

ההתקנה ממתינה עד 5 דקות למתג ואומרת כשהכלי מוכן. גם אם המתג מופעל מאוחר יותר, הכלי מזהה את האישור לבד ומציג "הפוך שפה מוכן", בלי להריץ שוב את ההתקנה.

### שימוש

1. הקלדתם משהו בשפה הלא נכונה? לוחצים <kbd>Ctrl</kbd>+<kbd>Option</kbd>+<kbd>L</kbd>. המילה האחרונה מתהפכת ומקור הקלט מתחלף.
2. צריך להפוך עוד מילים אחורה? לוחצים שוב, מהר (עד 2 שניות בין לחיצה ללחיצה). אפשר גם להחזיק את Ctrl+Option ולהקיש L כמה פעמים.
3. רוצים להפוך קטע מסוים? מסמנים אותו ולוחצים.

תפריט הסמל אA בשורת התפריטים: השהיה, פתיחת קובץ ההגדרות וטעינה מחדש.

### הגדרות

קובץ ההגדרות: `~/.hammerspoon/hafuch-safa/config.ini` (או מהתפריט של אA: "פתח את קובץ ההגדרות"). שמות המפתחות זהים לגרסת ה-Windows. אחרי שינוי בוחרים "טען מחדש" בתפריט.

| הגדרה | ברירת מחדל | מה היא עושה |
|---|---|---|
| `Hotkey` | `Ctrl+Option+L` | שילוב המקשים. אפשר גם `Ctrl+Alt+L` (כמו ב-Windows), `Cmd+Shift+K`, `Ctrl+Option+F9` |
| `HebrewLayout` | `auto` | `auto` לפי מקור הקלט העברי שמוגדר, `mac` הוא Hebrew, `pc` הוא Hebrew-PC (גם `standard`), `qwerty` הוא Hebrew-QWERTY |
| `SwitchLayout` | `1` | להחליף את מקור הקלט אחרי ההיפוך |
| `ExpandWindowMs` | `2000` | כמה זמן לחיצה נוספת מרחיבה את ההיפוך |
| `InsertMethod` | `type` | `type` מקליד את הטקסט המתוקן, `paste` מדביק אותו דרך הלוח |
| `TerminalInsertMethod` | `type` | אותו דבר בטרמינלים |
| `ShowTips` | `1` | הודעה קטנה כשאין מה להפוך |
| `ShowMenuBarIcon` | `1` | הסמל אA בשורת התפריטים |
| `ExcludeApps` | ריק | אפליקציות שבהן הקיצור לא יופעל, בשם או במזהה, מופרדות בפסיק (למשל `Microsoft Word,com.jetbrains.*`) |
| `DebugLog` | `0` | יומן אבחון. נרשמים בו רק אורכים ותוצאות, לעולם לא הטקסט |

### מה שונה במק

- מקור הקלט Hebrew של macOS מקליד במקש `w` את הגרש העברי `׳` ולא גרש רגיל. הכלי הופך את שניהם ל-`w`.
- טקסט מסומן שיש בו ירידת שורה מודבק תמיד דרך הלוח, כי Enter שולח הודעה באפליקציות צ'אט.
- הכלי זוכר את מה שהקלדתם באפליקציה שבחזית. לחיצת עכבר, חיצים, Enter, Tab, קיצור עם Cmd או Ctrl ומעבר אפליקציה מאפסים את הזיכרון. אחרי איפוס הכלי מסמן את המילה שלפני הסמן בעצמו (Option+Shift+Left), או שמסמנים ידנית ולוחצים.
- תיקון אוטומטי של macOS עלול לשנות מילה שהוקלדה לפני הלחיצה. במקרה כזה מסמנים את המילה ולוחצים.
- מי שהחליף בין Control ל-Command (הגדרות המערכת > מקלדת > מקשי צירוף, או hidutil, נפוץ אצל מי שמגיע מ-Windows): המקש Control שולח אצלו Command, ולכן Ctrl+Option+L לא היה מגיע לכלי. ההתקנה מזהה את ההחלפה ומגדירה `Hotkey=Cmd+Option+L`, כך שעל המקלדת לוחצים Control+Option+L כמו ב-Windows. בהתקנה חוזרת קובץ ההגדרות הקיים נשמר כמו שהוא.
- `Ctrl+Option+L` לא תפוס במערכת ולא באפליקציות הנפוצות שנבדקו. אם הוא מתנגש אצלכם במשהו, משנים את `Hotkey` או מוסיפים את האפליקציה ל-`ExcludeApps`.

### הסרה

```
bash ~/.hammerspoon/hafuch-safa/uninstall.sh
```

ההסרה מוחקת את השורה שנוספה ל-`init.lua` (ורק אותה), את התיקייה `~/.hammerspoon/hafuch-safa`, ואת `init.lua` עצמו אם ההתקנה יצרה אותו והוא נשאר ריק. אם לא נשארו הגדרות Hammerspoon אחרות, היא מבטלת את ההפעלה בכניסה וסוגרת את Hammerspoon, ואם ההתקנה היא שהתקינה אותו, גם מסירה אותו. אפשרויות: `--keep-config` שומר את קובץ ההגדרות, `--keep-hammerspoon` לא נוגע ב-Hammerspoon. את הרשומה של Hammerspoon ברשימת הנגישות אפשר להסיר ידנית בהגדרות המערכת.

### בדיקות

```
bash mac/tests/run-tests.sh --e2e
```

- `mac/tests/unit-tests.lua`: 111 בדיקות לפונקציות ההמרה. 83 הראשונות הן הבדיקות של Windows אחת לאחת.
- `mac/tests/layout-dump.swift`: מדפיס מה כל מקש מקליד במקורות הקלט העבריים והאנגליים של macOS, לבדיקת טבלאות המיפוי.
- `mac/tests/e2e-test.lua`: פותח מסמך משלו ב-TextEdit, מקליד בו הקשות אמיתיות ולוחץ על הקיצור שמוגדר ב-`config.ini` מול הכלי המותקן, ובודק את הטקסט, את מקור הקלט ואת הלוח. בזמן הריצה (כ-30 שניות) לא נוגעים במקלדת ובעכבר ולא עוברים לחלון אחר. הבדיקה נעצרת מעצמה אם חלון אחר עולה לחזית.

## כללי ההמרה

כל תו מומר לתו שנמצא על אותו מקש בפריסה השנייה. כמה תווים קיימים בשתי הפריסות על מקשים שונים, ואצלם הכיוון קובע:

| תו | אנגלית לעברית | עברית לאנגלית |
|---|---|---|
| `,` | `ת` | `'` |
| `.` | `ץ` | `/` |
| `/` | `.` | `q` |
| `'` | `,` | `w` |
| `;` | `ף` | `` ` `` |

- אותיות גדולות באנגלית נהפכות לאותה אות עברית כמו האותיות הקטנות, כך שגם טקסט שהוקלד עם Caps Lock מתוקן.
- מעברית לאנגלית יוצאות אותיות קטנות, ואות גדולה שהוקלדה עם Shift נשארת גדולה.
- הסוגריים `( ) [ ] { } < >` הפוכים בפריסה העברית של Windows, והכלי מתנהג בדיוק כמוה.
- אין מילון: הכלי תמיד הופך כשלוחצים, גם טקסט שכבר נכון. לחיצה נוספת מחזירה.

כל ההחלטות וההנחות מפורטות ב-[ASSUMPTIONS.md](ASSUMPTIONS.md).

## מגבלות

- הכלי זוכר את מה שהקלדתם בחלון הנוכחי כדי לדעת מה המילה האחרונה. לחיצת עכבר, חיצים, Enter או מעבר חלון מאפסים את הזיכרון. אחרי איפוס הכלי מסמן את המילה שלפני הסמן בעצמו, או שמסמנים ידנית ולוחצים.
- בטרמינלים הכלי הופך רק מילים שהוקלדו מאז הלחיצה האחרונה על Enter.
- Windows חוסם הקשות לחלונות שרצים כמנהל, ולכן הכלי לא עובד בהם.
- בתוכנות עם תיקון אוטומטי (כמו Word), הטקסט המתוקן מוקלד כמו כל הקלדה רגילה, ותיקון אוטומטי עשוי לפעול עליו.

## פרטיות

- הכלי פועל מקומית בלבד ולא ניגש לרשת.
- זיכרון ההקלדה נשמר רק בזיכרון המחשב (עד 500 תווים), לא נכתב לדיסק, ומתאפס ב-Enter, בלחיצת עכבר ובמעבר חלון.
- תוכן הלוח חוזר למקומו אחרי כל פעולה, ומה שהכלי שם בלוח מסומן כך שלא ייאסף להיסטוריית הלוח ולא יסונכרן לענן.

## הסרה

הכי פשוט: <kbd>Win</kbd>+<kbd>R</kbd>, מדביקים את השורה הבאה ולוחצים Enter (עובד גם ב-cmd):

```
%LOCALAPPDATA%\hafuch-safa\uninstall.cmd
```

או לחיצה כפולה על `uninstall.cmd` בתיקיית ההתקנה `%LOCALAPPDATA%\hafuch-safa`, או מ-PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\hafuch-safa\uninstall.ps1"
```

ההסרה עוצרת את הכלי, מוחקת את קיצור הדרך מתיקיית ההפעלה ואת תיקיית ההתקנה, ומסירה את AutoHotkey אם ההתקנה היא שהתקינה אותו. אפשרויות: `-KeepConfig` שומר את קובץ ההגדרות, `-KeepAutoHotkey` משאיר את AutoHotkey.

## בדיקות

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1 -E2E
```

- `tests\unit-tests.ahk`: 83 בדיקות לפונקציית ההמרה.
- `tests\layout-check.ahk`: משווה את טבלת המיפוי לפריסות שמותקנות אצלכם.
- `tests\e2e-test.ahk`: פותח חלון בדיקה משלו, מקליד בו הקשות אמיתיות ולוחץ על הקיצור מול הכלי המותקן, ובודק את הטקסט, את פריסת המקלדת ואת הלוח. בזמן הריצה (כ-20 שניות) לא נוגעים במקלדת ובעכבר.

## מבנה הפרויקט

```
hafuch-safa.ahk       הכלי עצמו: קיצור, זיכרון הקלדה, היפוך, החלפת פריסה
lib\core.ahk          לוגיקת ההמרה (פונקציות טהורות, עם בדיקות)
lib\layouts.ahk       טבלאות המיפוי המובנות
lib\system.ahk        פריסות מקלדת, לוח וחלונות של Windows
config.ini            קובץ ההגדרות
install.ps1           התקנה בפקודה אחת (install.cmd ללחיצה כפולה)
uninstall.ps1         הסרה (uninstall.cmd ללחיצה כפולה)
tests\                בדיקות

get.sh                התקנה בשורה אחת ל-macOS
mac/hafuch-safa/      הכלי ל-macOS (מודול Hammerspoon): init.lua, core.lua
mac/config.ini        קובץ ההגדרות של macOS
mac/install.sh        התקנה ל-macOS
mac/uninstall.sh      הסרה ל-macOS
mac/tests/            בדיקות ל-macOS
```

## תרומה

באגים, רעיונות ותיקונים מתקבלים בברכה ב-Issues וב-Pull Requests. לפני שליחת שינוי כדאי להריץ את הבדיקות.

## רישיון

[MIT](LICENSE)

---

## English

**hafuch-safa** ("flip language") fixes text typed in the wrong keyboard layout on Windows and macOS, between Hebrew and English. Typed `akuo` instead of "שלום"? Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd> (on a Mac <kbd>Ctrl</kbd>+<kbd>Option</kbd>+<kbd>L</kbd>): the text flips to the right language and the keyboard layout switches, so you can keep typing.

- With a selection, only the selection flips. Without one, the last typed word flips, and each extra press within 2 seconds extends the flip one more word back.
- The direction follows the majority of letters. Digits, spaces and shared symbols stay as they are.
- The key map is read from the layouts installed in Windows, so any Hebrew or English variant works.
- Selected text is read through the clipboard, and the clipboard is restored right after.
- Install in one line (cmd, PowerShell or Win+R):

  ```
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.ps1 | iex"
  ```

  or download the project and double-click `install.cmd`. Either way AutoHotkey v2 is installed per user if needed, with no admin rights. Settings: `%LOCALAPPDATA%\hafuch-safa\config.ini`. Uninstall: `uninstall.cmd`.

**macOS 13 or later** (runs inside [Hammerspoon](https://www.hammerspoon.org). If it is missing, the installer downloads the official release, a pinned 1.1.1 checked by SHA256 and code signature; no Homebrew, no admin password). Install in one line from Terminal:

```
curl -fsSL https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.sh | bash
```

- Hotkey: <kbd>Ctrl</kbd>+<kbd>Option</kbd>+<kbd>L</kbd>. Settings: `~/.hammerspoon/hafuch-safa/config.ini` (same keys as on Windows).
- One manual step: when System Settings opens at **Privacy & Security > Accessibility**, turn on **Hammerspoon** (macOS may ask about Hammerspoon first: click Open System Settings). macOS requires this before any app may read typing or send keystrokes. The installer waits for the switch and says when the tool is ready.
- Control and Command swapped (Modifier Keys or hidutil, common after Windows): the installer notices and sets `Hotkey=Cmd+Option+L`, so the keys marked Control+Option+L work.
- The installer adds a single line to the end of `~/.hammerspoon/init.lua` and changes nothing else there.
- Uninstall: `bash ~/.hammerspoon/hafuch-safa/uninstall.sh` (removes that line, the module, and Hammerspoon too if the installer installed it and nothing else uses it).
- Tests: `bash mac/tests/run-tests.sh --e2e` (111 unit tests, and an end-to-end test that types into a TextEdit document of its own).

MIT licensed.
