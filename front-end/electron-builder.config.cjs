const { RELEASE_OWNER, RELEASE_REPO } = require('./electron/release-config.cjs');

module.exports = {
    appId: 'com.yourname.memoryflow',
    productName: 'MemoryFlow',
    artifactName: '${productName}-Setup-${version}.${ext}',
    directories: {
        output: 'release_v2'
    },
    files: [
        'dist/**/*',
        'electron/**/*'
    ],
    win: {
        target: 'nsis',
        icon: 'build/icon.ico'
    },
    nsis: {
        oneClick: false,
        allowToChangeInstallationDirectory: true,
        createDesktopShortcut: true,
        createStartMenuShortcut: true,
        shortcutName: 'MemoryFlow'
    },
    protocols: {
        name: 'MemoryFlow Protocol',
        schemes: [
            'memoryflow'
        ]
    },
    publish: [
        {
            provider: 'github',
            owner: RELEASE_OWNER,
            repo: RELEASE_REPO,
            releaseType: 'release'
        }
    ]
};
