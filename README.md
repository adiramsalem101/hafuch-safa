<p align="center"><img src="assets/icon-256.png" width="96" alt="הפוך שפה"></p>

<h1 align="center">הפוך שפה (hafuch-safa)</h1>

<p align="center">הקלדתם בשפה הלא נכונה? לחיצה אחת, והטקסט מתהפך לשפה הנכונה.</p>

---

כלי קטן ל-Windows שמתקן טקסט שהוקלד בפריסת מקלדת לא נכונה. הקלדתם `akuo` כשהתכוונתם ל"שלום", או `יקךךם` כשהתכוונתם ל-`hello`? לוחצים <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd>, הטקסט מתהפך, ופריסת המקלדת של Windows עוברת לשפה הנכונה כדי שתמשיכו להקליד בלי לעצור.

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
- **החלפת פריסה:** אחרי ההיפוך Windows עובר לפריסה של השפה החדשה.
- **חזרה:** טעיתם? לחיצה על אותה מילה אחרי יותר מ-2 שניות מחזירה אותה בדיוק כפי שהייתה, כולל אותיות גדולות.
- **הלוח (clipboard):** טקסט מסומן נקרא דרך הלוח, ומה שהיה בלוח לפני כן חוזר למקומו מיד. מה שהכלי עצמו שם בלוח לא נאסף להיסטוריית הלוח של Windows (Win+V).

הכלי עובד בכל תוכנה שמקבלת הקלדה: דפדפנים, WhatsApp, Outlook ו-Gmail, Slack, Word, פנקס רשימות וטרמינלים.

## דרישות

- Windows 10 או Windows 11.
- פריסת מקלדת עברית ופריסת מקלדת אנגלית מותקנות (הגדרות > זמן ושפה > שפה ואזור).
- [AutoHotkey v2](https://www.autohotkey.com). אם הוא חסר, ההתקנה מתקינה אותו לבד דרך winget, למשתמש הנוכחי בלבד, בלי הרשאות מנהל.

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

- מתקינה AutoHotkey v2 אם הוא חסר (winget, ברמת המשתמש).
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
```

## תרומה

באגים, רעיונות ותיקונים מתקבלים בברכה ב-Issues וב-Pull Requests. לפני שליחת שינוי כדאי להריץ את הבדיקות.

## רישיון

[MIT](LICENSE)

---

## English

**hafuch-safa** ("flip language") fixes text typed in the wrong keyboard layout on Windows, between Hebrew and English. Typed `akuo` instead of "שלום"? Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>L</kbd>: the text flips to the right language and the Windows keyboard layout switches, so you can keep typing.

- With a selection, only the selection flips. Without one, the last typed word flips, and each extra press within 2 seconds extends the flip one more word back.
- The direction follows the majority of letters. Digits, spaces and shared symbols stay as they are.
- The key map is read from the layouts installed in Windows, so any Hebrew or English variant works.
- Selected text is read through the clipboard, and the clipboard is restored right after.
- Install in one line (cmd, PowerShell or Win+R):

  ```
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.ps1 | iex"
  ```

  or download the project and double-click `install.cmd`. Either way AutoHotkey v2 is installed per user if needed, with no admin rights. Settings: `%LOCALAPPDATA%\hafuch-safa\config.ini`. Uninstall: `uninstall.cmd`.

MIT licensed.
