// Pegasus Frontend
// Copyright (C) 2017-2020  Mátyás Mustoha
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


#include "backend/Backend.h"
#include "backend/Paths.h"
#include "backend/platform/TerminalKbd.h"

#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QSettings>
#include <QtPlugin>

#ifdef Q_OS_ANDROID
#include "backend/platform/AndroidHelpers.h"
#include <QEventLoop>
#include <QTimer>
#include <QtAndroidExtras/QAndroidJniObject>
#endif


#ifdef WITH_APNG_SUPPORT
Q_IMPORT_PLUGIN(ApngImagePlugin)
#endif


backend::CliArgs handle_cli_args(QGuiApplication&);
bool request_runtime_permissions();
bool portable_txt_present();
void p7_first_run_setup();

int main(int argc, char *argv[])
{
    Q_INIT_RESOURCE(frontend);
    Q_INIT_RESOURCE(themes);
    Q_INIT_RESOURCE(qmlutils);
#ifdef PEGASUS_USING_CMAKE  // TODO: Unify the build system
    Q_INIT_RESOURCE(assets);
    Q_INIT_RESOURCE(locales);
    Q_INIT_RESOURCE(qmlutils_qmlcache);
    Q_INIT_RESOURCE(frontend_qmlcache);
    Q_INIT_RESOURCE(themes_qmlcache);
#endif

    TerminalKbd::on_startup();

    QCoreApplication::addLibraryPath(QStringLiteral("lib/plugins"));
    QCoreApplication::addLibraryPath(QStringLiteral("lib"));
    QSettings::setDefaultFormat(QSettings::IniFormat);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("pegasus-frontend"));
    app.setApplicationVersion(QStringLiteral(GIT_REVISION));
    app.setOrganizationName(QStringLiteral("pegasus-frontend"));
    app.setOrganizationDomain(QStringLiteral("pegasus-frontend.org"));
    app.setWindowIcon(QIcon(QStringLiteral(":/icon.png")));

    if (!request_runtime_permissions())
        return 1;

    p7_first_run_setup();

    backend::CliArgs cli_args = handle_cli_args(app);
    cli_args.portable |= portable_txt_present();

    backend::Backend backend(cli_args);
    backend.start();

    return app.exec();
}

bool request_runtime_permissions()
{
#ifdef Q_OS_ANDROID
    if (android::has_external_storage_access())
        return true;

    // P7 Station: o Android abriu a tela "Acesso a todos os arquivos". Antes o app encerrava aqui
    // e ficava uma tela branca ao voltar; agora ele espera a permissão e segue normalmente.
    QEventLoop wait_loop;
    QTimer poll;
    QObject::connect(&poll, &QTimer::timeout, [&wait_loop](){
        const bool granted = QAndroidJniObject::callStaticMethod<jboolean>(
            "org/pegasus_frontend/android/MainActivity", "hasAllStorageAccess");
        if (granted)
            wait_loop.quit();
    });
    poll.start(600);
    wait_loop.exec();
    return android::has_external_storage_access();
#endif

    return true;
}


bool portable_txt_present()
{
#ifdef Q_OS_ANDROID
    // NOTE: On Android, the executable location is not generally accessible
    return false;
#else
    const QString path = paths::app_dir_path() + QStringLiteral("/portable.txt");
    return QFileInfo::exists(path);
#endif
}


QCommandLineOption add_cli_option(QCommandLineParser& parser, const QString& name, const QString& desc)
{
    QCommandLineOption arg(name, desc);
    parser.addOption(arg);
    return arg;
}

backend::CliArgs handle_cli_args(QGuiApplication& app)
{
#define CMDMSG QStringLiteral

    QCommandLineParser argparser;
    argparser.setApplicationDescription(CMDMSG(
        "\nPegasus is a graphical frontend for browsing your game library (especially\n"
        "retro games) and launching them from one place. It's focusing on customization,\n"
        "cross platform support (including embedded devices) and high performance."));

    const QCommandLineOption arg_portable = add_cli_option(argparser,
        QStringLiteral("portable"),
        CMDMSG("Do not read or write config files outside the program's directory"));

    const QCommandLineOption arg_silent = add_cli_option(argparser,
        QStringLiteral("silent"),
        CMDMSG("Do not print log messages to the terminal"));

    const QCommandLineOption arg_menu_reboot = add_cli_option(argparser,
        QStringLiteral("disable-menu-reboot"),
        CMDMSG("Hides the system reboot entry in the main menu"));

    const QCommandLineOption arg_menu_shutdown = add_cli_option(argparser,
        QStringLiteral("disable-menu-shutdown"),
        CMDMSG("Hides the system shutdown entry in the main menu"));

    const QCommandLineOption arg_menu_suspend = add_cli_option(argparser,
        QStringLiteral("disable-menu-suspend"),
        CMDMSG("Hides the system suspend entry in the main menu"));

    const QCommandLineOption arg_menu_appclose = add_cli_option(argparser,
        QStringLiteral("disable-menu-appclose"),
        CMDMSG("Hides the closing Pegasus entry in the main menu"));

    const QCommandLineOption arg_menu_settings = add_cli_option(argparser,
        QStringLiteral("disable-menu-settings"),
        CMDMSG("Hides the settings menu entry in the main menu"));

    const QCommandLineOption arg_menu_kiosk = add_cli_option(argparser,
        QStringLiteral("kiosk"),
        CMDMSG("Alias for:\n"
               "--disable-menu-reboot\n"
               "--disable-menu-shutdown\n"
               "--disable-menu-appclose\n"
               "--disable-menu-settings"));

    const QCommandLineOption arg_gamepad_autoconfig = add_cli_option(argparser,
        QStringLiteral("disable-gamepad-autoconfig"),
        CMDMSG("Disables the automatic layout detection for connected gamepads.\n"
               "When you connect a gamepad, Pegasus tries to guess its button and axis layout "
               "automatically based on a list of known devices. Unfortunately this doesn't seem "
               "to work perfectly with some platforms and devices (eg. arcades), in which case "
               "you can disable this feature here."));

    argparser.addHelpOption();
    argparser.addVersionOption();
    argparser.process(app); // may quit!

    backend::CliArgs args;
    args.portable = argparser.isSet(arg_portable);
    args.silent = argparser.isSet(arg_silent);
    args.enable_menu_appclose = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_appclose));
    args.enable_menu_settings = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_settings));
    args.enable_gamepad_autoconfig = !argparser.isSet(arg_gamepad_autoconfig);
#ifdef Q_OS_ANDROID
    args.enable_menu_shutdown = false;
    args.enable_menu_reboot = false;
#else
    args.enable_menu_shutdown = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_shutdown));
    args.enable_menu_reboot = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_reboot));
#endif
#if defined(Q_OS_ANDROID) || defined(Q_OS_WINDOWS) || defined(Q_OS_MAC)
    args.enable_menu_suspend = false;
#else
    args.enable_menu_suspend = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_suspend));
#endif
    return args;

#undef CMDMSG
}


// ---------------------------------------------------------------- P7 Station
// Cria a pasta de jogos com uma subpasta por console, o arquivo que diz qual emulador
// abre cada console e registra a pasta como pasta de jogos. Roda a cada abertura e só
// mexe no que falta (ou no arquivo de emuladores, enquanto ele tiver a marca automática).
void p7_first_run_setup()
{
#ifdef Q_OS_ANDROID
    static const char METADATA[] = R"P7(# P7STATION-AUTO v1
# Arquivo criado pelo P7 Station. Ele é atualizado sozinho a cada versão do app.
# Se quiser editar (por exemplo, usar a linha alternativa de um emulador),
# APAGUE a primeira linha deste arquivo: assim o app não substitui suas mudanças.
# ==================================================================
#  Hub de Jogos - consoles e emuladores
#  Este arquivo fica dentro da pasta "Jogos", junto das pastas
#  snes, psx, ps2, wiiu e switch.
#
#  Cada bloco diz ao Pegasus:
#    - quais arquivos são jogos (extensions)
#    - em que pasta eles estão (directories)
#    - como abrir o emulador direto no jogo (launch)
#
#  Linhas que começam com # são comentários e não fazem nada.
# ==================================================================


# ------------------------------------------------------------------
#  SUPER NINTENDO  ->  RetroArch (núcleo Snes9x)
# ------------------------------------------------------------------
collection: Super Nintendo
shortname: snes
directories: snes
extensions: sfc, smc, fig, swc, zip, 7z
launch: am start --user 0
  -n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch.aarch64/cores/snes9x_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg
  -e QUITFOCUS 1
  --activity-clear-task --activity-clear-top --activity-no-history


# ------------------------------------------------------------------
#  PLAYSTATION 1  ->  RetroArch (núcleo PCSX ReARMed)
#  Prefira jogos em .chd (1 arquivo por jogo). Se usar .cue + .bin,
#  só o .cue aparece na lista - é assim mesmo.
# ------------------------------------------------------------------
collection: PlayStation
shortname: psx
directories: psx
extensions: chd, pbp, cue, m3u
launch: am start --user 0
  -n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture
  -e ROM {file.path}
  -e LIBRETRO /data/data/com.retroarch.aarch64/cores/pcsx_rearmed_libretro_android.so
  -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg
  -e QUITFOCUS 1
  --activity-clear-task --activity-clear-top --activity-no-history


# ------------------------------------------------------------------
#  PLAYSTATION 2  ->  NetherSX2
#  O NetherSX2 precisa ter acesso à pasta Jogos/ps2 (ele pede na
#  primeira vez que você escolhe a pasta de jogos dentro dele).
# ------------------------------------------------------------------
collection: PlayStation 2
shortname: ps2
directories: ps2
extensions: chd, iso, cso, zso
launch: am start --user 0
  -n xyz.aethersx2.android/.EmulationActivity
  -a android.intent.action.MAIN
  --es bootPath {file.documenturi}
  --activity-clear-task --activity-clear-top
# Se o seu NetherSX2 for a versão "Turnip", troque a linha do -n acima por:
#   -n xyz.aethersx2.tturnip/xyz.aethersx2.android.EmulationActivity


# ------------------------------------------------------------------
#  WII U  ->  Cemu
#  Use jogos em .wua (1 arquivo por jogo).
#  O Cemu precisa ter acesso à pasta Jogos/wiiu (adicione dentro do
#  Cemu em "Game paths").
# ------------------------------------------------------------------
collection: Wii U
shortname: wiiu
directories: wiiu
extensions: wua, wud, wux, rpx
launch: am start --user 0
  -n info.cemu.cemu/info.cemu.cemu.emulation.EmulationActivity
  -d {file.documenturi}
# Se o Cemu não abrir, troque a linha do -n acima por:
#   -n info.cemu.Cemu/info.cemu.Cemu.emulation.EmulationActivity


# ------------------------------------------------------------------
#  NINTENDO SWITCH  ->  Eden
#  Precisa das chaves (prod.keys) e do firmware instalados no Eden.
# ------------------------------------------------------------------
collection: Nintendo Switch
shortname: switch
directories: switch
extensions: nsp, xci
launch: am start --user 0
  -n dev.eden.eden_emulator/org.yuzu.yuzu_emu.activities.EmulationActivity
  -a android.nfc.action.TECH_DISCOVERED
  -d {file.uri}
# Se você instalou a versão "legacy" do Eden, troque a linha do -n por:
#   -n dev.legacy.eden_emulator/org.yuzu.yuzu_emu.activities.EmulationActivity
)P7";

    const QString games_root = QStringLiteral("/storage/emulated/0/Jogos");
    QDir dir;
    for (const char* sub : {"snes", "psx", "ps2", "wiiu", "switch", "_bios"})
        dir.mkpath(games_root + QChar('/') + QLatin1String(sub));

    const QByteArray wanted(METADATA);
    QFile meta(games_root + QStringLiteral("/metadata.pegasus.txt"));
    bool write_meta = true;
    if (meta.exists() && meta.open(QIODevice::ReadOnly)) {
        const QByteArray current = meta.readAll();
        meta.close();
        write_meta = current != wanted && current.startsWith("# P7STATION-AUTO");
    }
    if (write_meta && meta.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        meta.write(wanted);
        meta.close();
    }

    QFile gamedirs(paths::writableConfigDir() + QStringLiteral("/game_dirs.txt"));
    QByteArray listed;
    if (gamedirs.open(QIODevice::ReadOnly)) {
        listed = gamedirs.readAll();
        gamedirs.close();
    }
    if (!listed.split('\n').contains(games_root.toUtf8())
        && gamedirs.open(QIODevice::Append | QIODevice::Text)) {
        if (!listed.isEmpty() && !listed.endsWith('\n'))
            gamedirs.write("\n");
        gamedirs.write(games_root.toUtf8() + "\n");
        gamedirs.close();
    }
#endif
}
