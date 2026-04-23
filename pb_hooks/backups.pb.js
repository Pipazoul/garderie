onBootstrap((e) => {
    e.next()

    const settings = e.app.settings()
    settings.backups.cron = "0 * * * *"
    settings.backups.cronMaxKeep = 24
    e.app.save(settings)
})
