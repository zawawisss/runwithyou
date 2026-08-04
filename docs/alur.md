PROJECT DOCUMENTATION
Nama Aplikasi: RunWithYou
Tujuan Utama
Aplikasi fitness + task manager untuk pacar saya — seorang guru perempuan yang suka jogging tetapi memiliki jadwal padat (mengajar + les malam).
Target User

Nama panggilan: [isi nama pacar kamu]
Profesi: Guru + les malam
Kebutuhan utama: Olahraga (jogging) yang fleksibel, manajemen tugas, tracking kesehatan, dan rekomendasi pintar sesuai jadwal sibuk.


Fitur Utama (MVP)
1. Dashboard Utama

Ringkasan harian: Sleep, Langkah, Kalori, Heart Rate rata-rata
Rekomendasi AI (pakai OpenRouter)
Jadwal hari ini (sekolah + les)
Energy level hari ini

2. Jogging Tracker

One-tap "Mulai Jogging"
Real-time tracking (jarak, pace, waktu, heart rate via Health Connect)
Auto pause/resume
Voice feedback
Save workout otomatis

3. Health Connect Integration

Sync data via Google Health Connect (langkah, HR, sleep, workout)
Data Huawei Band masuk lewat bridge pihak ketiga "Health Sync" (Huawei Health → Health Connect)
Real-time heart rate (kalau memungkinkan; via bridge sifatnya mengikuti ritme sinkron, bukan streaming)

4. Task Manager

To-do list harian
Integrasi dengan jadwal les/mengajar
Energy-based task suggestion (AI)

5. AI Assistant (OpenRouter)

Rekomendasi workout & jadwal
Motivasi personal
Analisis progress mingguan

6. Progress & History

Statistik mingguan/bulanan
Grafik progress
Achievement / streak

7. Lainnya

Safety features (share live location)
Dark mode + tema feminine
Reminder pintar


Teknologi Stack

Framework: Flutter (Android focus dulu)
State Management: Riverpod
Backend AI: OpenRouter (Google Gemini / Llama / dll)
Health Integration: Google Health Connect (health) — Huawei Band via "Health Sync" bridge
Database Lokal: Hive atau Isar
Charts: fl_chart
HTTP Client: Dio
Deployment: Android (Web nanti)


Desain & Branding

Nama: RunWithYou
Tagline: "Langkah bersama menuju sehat & bahagia"
Warna Utama:
Primary: Soft Pink / Peach (#FF8A9B)
Accent: Teal / Mint Green
Background: Warm White + Dark Mode

Style: Feminine, clean, calming, sporty


Instruksi untuk AI Agent / Developer

Mulai dengan setup project Flutter + Google Health Connect integration.
Buat UI yang cantik, feminine, dan mudah digunakan.
Prioritaskan fitur MVP: Dashboard → Jogging Tracker → Health Sync → Task Manager.
AI features harus ramah, suportif, dan memahami jadwal guru yang sibuk.
Selalu prioritaskan simplicity dan emotional support.


Catatan Tambahan

Aplikasi ini adalah project spesial untuk pacar saya. Jaga tone-nya tetap hangat dan positif.
Bahasa aplikasi: Bahasa Indonesia.
Harus support smartwatch yang sinkron ke Health Connect (termasuk Huawei Band via bridge "Health Sync").


Mau saya tambahkan bagian lain? Misalnya:

User Flow lengkap
Database Schema
API Structure
Feature Backlog (prioritas)
