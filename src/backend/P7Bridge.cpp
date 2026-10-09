// P7 Station: ponte entre o tema e o sistema (pacotes instalados, pastas e arquivos).
#include "P7Bridge.h"

#include "Paths.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QTextStream>

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
