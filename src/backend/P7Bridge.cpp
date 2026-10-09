// P7 Station: ponte entre o tema e o sistema (pacotes instalados, pastas e arquivos).
#include "P7Bridge.h"

#include "Paths.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QTextStream>
#include <QVariantMap>
#include <QHash>
#include <QRegularExpression>
#include <vector>

#ifdef Q_OS_ANDROID
#include "platform/AndroidHelpers.h"
#include <QtAndroidExtras/QAndroidJniObject>
#endif


P7Bridge::P7Bridge(QObject* parent)
    : QObject(parent)
{}

QStringList P7Bridge::installedPackages() const
{
#ifdef Q_OS_ANDROID
    const QAndroidJniObject result = QAndroidJniObject::callStaticObjectMethod(
        android::jni_classname(), "installedPackages", "()Ljava/lang/String;");
    return result.toString().split(QChar('\n'), Qt::SkipEmptyParts);
#else
    return {};
#endif
}

QVariantList P7Bridge::switchEmulators() const
{
    QVariantList out;
#ifdef Q_OS_ANDROID
    const QAndroidJniObject result = QAndroidJniObject::callStaticObjectMethod(
        android::jni_classname(), "switchEmulators", "()Ljava/lang/String;");
    const QStringList lines = result.toString().split(QChar('\n'), Qt::SkipEmptyParts);
    for (const QString& line : lines) {
        const QStringList f = line.split(QChar('\t'));
        if (f.size() < 4)
            continue;
        QVariantMap m;
        m[QStringLiteral("pkg")] = f[0];
        m[QStringLiteral("activity")] = f[1];
        m[QStringLiteral("label")] = f[2].trimmed();
        m[QStringLiteral("updated")] = f[3].toDouble();
        out << m;
    }
#endif
    return out;
}

QStringList P7Bridge::subdirs(const QString& path) const
{
    QDir dir(path);
    if (!dir.exists())
        return {};
    QStringList names = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable, QDir::Name | QDir::IgnoreCase);
    QStringList out;
    for (const QString& n : names) {
        if (n.startsWith(QChar('.')))
            continue;
        out << n;
    }
    return out;
}

bool P7Bridge::isDir(const QString& path) const
{
    return !path.isEmpty() && QFileInfo(path).isDir();
}

int P7Bridge::countFiles(const QString& path, const QStringList& extensions) const
{
    if (path.isEmpty())
        return 0;
    QStringList filters;
    for (const QString& e : extensions)
        filters << QStringLiteral("*.") + e;
    int count = 0;
    QDirIterator it(path, filters, QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
    while (it.hasNext() && count < 100000) {
        it.next();
        count++;
    }
    return count;
}

QString P7Bridge::readText(const QString& path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    QTextStream stream(&file);
    stream.setCodec("UTF-8");
    return stream.readAll();
}

bool P7Bridge::writeText(const QString& path, const QString& text) const
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    QTextStream stream(&file);
    stream.setCodec("UTF-8");
    stream << text;
    stream.flush();
    return file.commit();
}

QString P7Bridge::libraryDir() const
{
    return paths::writableConfigDir() + QStringLiteral("/biblioteca");
}

QString P7Bridge::storageRoot() const
{
#ifdef Q_OS_ANDROID
    const QString primary = android::primary_storage_path();
    if (!primary.isEmpty())
        return primary;
    return QStringLiteral("/storage/emulated/0");
#else
    return QDir::homePath();
#endif
}

QVariantList P7Bridge::controllers() const
{
    QVariantList out;
#ifdef Q_OS_ANDROID
    const QAndroidJniObject result = QAndroidJniObject::callStaticObjectMethod(
        android::jni_classname(), "controllers", "()Ljava/lang/String;");
    const QStringList lines = result.toString().split(QChar('\n'), Qt::SkipEmptyParts);
    for (const QString& line : lines) {
        const QStringList f = line.split(QChar('\t'));
        if (f.size() < 4)
            continue;
        const bool present = f.at(1) == QLatin1String("1");
        const double capacity = f.at(2).toDouble();
        const int status = f.at(3).toInt();
        QVariantMap pad;
        pad.insert(QStringLiteral("name"), f.at(0));
        pad.insert(QStringLiteral("hasBattery"), present && capacity >= 0.0);
        pad.insert(QStringLiteral("level"), present && capacity >= 0.0 ? qRound(capacity * 100.0) : -1);
        pad.insert(QStringLiteral("charging"), present && status == 2);
        pad.insert(QStringLiteral("full"), present && status == 5);
        out << pad;
    }
#endif
    return out;
}

namespace { bool g_intro_shown = false; }

bool P7Bridge::introPending() const
{
    return !g_intro_shown;
}

void P7Bridge::introDone()
{
    g_intro_shown = true;
}

// ---------------------------------------------------------------- capas de Switch
// Índice gerado por tools/capas-switch/gerar_indice.py (nome normalizado, ID, código do ícone).
namespace {
struct SwitchIndex {
    QHash<QString, QString> by_name;
    QHash<QString, QString> by_id;
    std::vector<std::pair<QString, QString>> names;   // para a busca aproximada
    bool loaded = false;
};

SwitchIndex& switch_index()
{
    static SwitchIndex idx;
    if (idx.loaded)
        return idx;
    idx.loaded = true;
    QFile file(QStringLiteral(":/themes/hub-vidro/switch-capas.tsv"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return idx;
    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.isEmpty() || line.startsWith(QChar('#')))
            continue;
        const QStringList f = line.split(QChar('\t'));
        if (f.size() < 3)
            continue;
        if (!idx.by_name.contains(f.at(0))) {
            idx.by_name.insert(f.at(0), f.at(2));
            idx.names.emplace_back(f.at(0), f.at(2));
        }
        idx.by_id.insert(f.at(1), f.at(2));
    }
    return idx;
}

// igual a normalize() de tools/capas-switch/gerar_indice.py
QString normalize_title(const QString& title)
{
    QString t = title.normalized(QString::NormalizationForm_D);
    QString out;
    out.reserve(t.size());
    for (const QChar c : t) {
        if (c.category() == QChar::Mark_NonSpacing)
            continue;
        out.append(c);
    }
    out = out.toLower();
    out.remove(QChar(0x2122)).remove(QChar(0x00AE)).remove(QChar(0x00A9));
    static const QRegularExpression brackets(QStringLiteral("[\\(\\[][^\\)\\]]*[\\)\\]]"));
    out.remove(brackets);
    out.replace(QChar('&'), QStringLiteral(" and "));
    static const QRegularExpression the_word(QStringLiteral("\\bthe\\b"));
    out.remove(the_word);
    static const QRegularExpression non_alnum(QStringLiteral("[^a-z0-9]+"));
    out.remove(non_alnum);
    return out;
}

QString eshop_url(const QString& code)
{
    return QStringLiteral("https://img-eshop.cdn.nintendo.net/i/") + code + QStringLiteral(".jpg");
}
} // namespace

QString P7Bridge::switchCover(const QString& title, const QString& filePath) const
{
    const SwitchIndex& idx = switch_index();
    if (idx.by_name.isEmpty())
        return QString();

    // 1) ID do jogo no nome do arquivo: "Jogo [0100ABCD12340000][v0].nsp" (atualização/DLC -> jogo base)
    static const QRegularExpression id_re(QStringLiteral("\\b(01[0-9A-Fa-f]{14})\\b"));
    const QRegularExpressionMatch m = id_re.match(QFileInfo(filePath).fileName());
    if (m.hasMatch()) {
        const QString base = m.captured(1).toUpper().left(13) + QStringLiteral("000");
        const auto it = idx.by_id.constFind(base);
        if (it != idx.by_id.cend())
            return eshop_url(it.value());
    }

    // 2) título igual
    const QString key = normalize_title(title);
    if (key.isEmpty())
        return QString();
    const auto it = idx.by_name.constFind(key);
    if (it != idx.by_name.cend())
        return eshop_url(it.value());

    // 3) título contido no nome da eShop (ex.: "Zelda Tears of the Kingdom"), o mais curto que servir
    if (key.size() < 6)
        return QString();
    const QString* best = nullptr;
    int best_len = 0;
    for (const auto& entry : idx.names) {
        if (entry.first.contains(key) && (!best || entry.first.size() < best_len)) {
            best = &entry.second;
            best_len = entry.first.size();
        }
    }
    return best ? eshop_url(*best) : QString();
}
