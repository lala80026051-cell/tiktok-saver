# Get TikTok Saver on your own computer · ទទួល TikTok Saver លើកុំព្យូទ័ររបស់អ្នក

TikTok Saver saves videos from TikTok, YouTube, Facebook and Instagram, and can write the caption on the video.
It runs **on your own Windows computer**. It is free.

TikTok Saver រក្សាទុកវីដេអូពី TikTok, YouTube, Facebook និង Instagram ហើយអាចសរសេរ caption លើវីដេអូ។
វាដំណើរការ **លើកុំព្យូទ័រ Windows របស់អ្នកផ្ទាល់**។ វាឥតគិតថ្លៃ។

> 🙏 Only save **your own videos**, or videos where **the owner says OK**.
> រក្សាទុកតែ **វីដេអូរបស់អ្នកផ្ទាល់** ឬវីដេអូដែល **ម្ចាស់អនុញ្ញាត**។

---

## Why can it not just be a website? · ហេតុអ្វីវាមិនអាចជាគេហទំព័រធម្មតា?

A normal website on the internet (like the one on Cloudflare) is like a **menu on a wall**: it shows things, but it cannot cook.
Saving videos needs two programs that must run on a **real computer** (yt-dlp and ffmpeg). So each person runs their own copy.

គេហទំព័រធម្មតាលើអ៊ីនធឺណិត (ដូចគេហទំព័រលើ Cloudflare) ដូចជា **ម៉ឺនុយនៅលើជញ្ជាំង**៖ វាបង្ហាញអ្វីៗ ប៉ុន្តែវាមិនអាចចម្អិនម្ហូបបានទេ។
ការរក្សាទុកវីដេអូត្រូវការកម្មវិធីពីរ ដែលត្រូវរត់លើ **កុំព្យូទ័រពិតប្រាកដ** (yt-dlp និង ffmpeg)។ ដូច្នេះមនុស្សម្នាក់ៗរត់ច្បាប់ចម្លងរបស់ខ្លួន។

---

## Steps (one time) · ជំហាន (តែម្តង)

### 1. Download the app · ទាញយកកម្មវិធី
Download the zip file, then **unzip** it: right-click the file, then **Extract All**.

ទាញយកឯកសារ zip ហើយ **ពន្លា** វា៖ ចុចខាងស្តាំលើឯកសារ រួចជ្រើស **Extract All**។

### 2. Install Node.js · ដំឡើង Node.js
Node.js is free. Go to <https://nodejs.org> and install the **LTS** version.
Or, in PowerShell: `winget install OpenJS.NodeJS.LTS`

Node.js ឥតគិតថ្លៃ។ ចូលទៅ <https://nodejs.org> ហើយដំឡើងកំណែ **LTS**។
ឬក្នុង PowerShell៖ `winget install OpenJS.NodeJS.LTS`

### 3. Double-click `setup.bat` · ចុចពីរដងលើ `setup.bat`
It asks you first. Then it:
- installs the website parts,
- downloads **yt-dlp** (about 22 MB) and **ffmpeg** (about 193 MB) from their official GitHub pages,
- **checks each file** against the official checksum, and deletes it if it does not match,
- puts a **TikTok Saver icon on your Desktop**, so you can open the app with a double-click.

វាសួរអ្នកជាមុន។ បន្ទាប់មកវា៖
- ដំឡើងផ្នែកនៃគេហទំព័រ
- ទាញយក **yt-dlp** (ប្រហែល 22 MB) និង **ffmpeg** (ប្រហែល 193 MB) ពីទំព័រ GitHub ផ្លូវការរបស់ពួកវា
- **ពិនិត្យឯកសារនីមួយៗ** ជាមួយលេខត្រួតពិនិត្យផ្លូវការ ហើយលុបវា បើវាមិនត្រូវគ្នា
- ដាក់ **រូបតំណាង TikTok Saver លើ Desktop** របស់អ្នក ដើម្បីឱ្យអ្នកបើកកម្មវិធីបានដោយចុចពីរដង។

> If you see "running scripts is disabled", do not worry: `setup.bat` handles that for its own run only.
> It does not change any setting of your computer.

### 4. Double-click the **TikTok Saver** icon on your Desktop · ចុចពីរដងលើរូបតំណាង **TikTok Saver** លើ Desktop
(Or double-click `start.bat` in the folder. It does the same.)
Two black windows open, and then your browser opens your own page (`http://localhost:4323`).
Keep the black windows open while you use the page.
If you move the folder, run `setup.bat` again to make a new icon.

(ឬចុចពីរដងលើ `start.bat` ក្នុងថត។ វាធ្វើដូចគ្នា។)
បង្អួចខ្មៅពីរបើក ហើយបន្ទាប់មក browser របស់អ្នកបើកទំព័រផ្ទាល់ខ្លួន (`http://localhost:4323`)។
ទុកបង្អួចខ្មៅបើក ខណៈពេលអ្នកប្រើទំព័រ។
បើអ្នកផ្លាស់ទីថត សូមរត់ `setup.bat` ម្តងទៀតដើម្បីបង្កើតរូបតំណាងថ្មី។

---

## Using it · ការប្រើប្រាស់

1. Choose the site: TikTok, YouTube, Facebook or Instagram.
2. Paste the link of the video.
3. Choose the folder, the quality, and whether to put the caption on the video.
4. Press **Download 1 video**. Videos are saved as `001 - caption.mp4`, `002 - ...`.

១. ជ្រើសរើសវេទិកា៖ TikTok, YouTube, Facebook ឬ Instagram។
២. បិទភ្ជាប់តំណរបស់វីដេអូ។
៣. ជ្រើសរើសថត គុណភាព និងថាតើត្រូវដាក់ caption លើវីដេអូឬអត់។
៤. ចុច **Download 1 video**។ វីដេអូត្រូវបានរក្សាទុកជា `001 - caption.mp4`, `002 - ...`។

## Good to know · ដែលគួរដឹង

- **TikTok has no 4K.** You get the best quality that the site has.
- **Facebook and Instagram** often ask people to log in. This app cannot log in, so private posts do not work.
- Windows only for now.
- Phone or other computer on the **same Wi-Fi**: double-click `start-network.bat` instead of `start.bat`. It shows an address and a 6-digit code.

- **TikTok គ្មាន 4K ទេ។** អ្នកទទួលបានគុណភាពល្អបំផុតដែលគេហទំព័រមាន។
- **Facebook និង Instagram** ច្រើនតែសុំឱ្យចូលគណនី។ កម្មវិធីនេះមិនអាចចូលគណនីបានទេ ដូច្នេះប្រកាសឯកជនមិនដំណើរការ។
- ដំណើរការលើ Windows សម្រាប់ពេលនេះ។
- ទូរស័ព្ទ ឬកុំព្យូទ័រផ្សេងលើ **Wi-Fi តែមួយ**៖ ចុចពីរដងលើ `start-network.bat` ជំនួស `start.bat`។ វាបង្ហាញអាសយដ្ឋាន និងលេខកូដ 6 ខ្ទង់។
