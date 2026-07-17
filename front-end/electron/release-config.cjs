const RELEASE_OWNER = 'xixi131';
const RELEASE_REPO = 'MemoryFlow.exe';
const RELEASE_REPOSITORY = `${RELEASE_OWNER}/${RELEASE_REPO}`;
const RELEASE_TAG_PATTERN_SOURCE = '^win-v\\d+\\.\\d+\\.\\d+(?:-[0-9A-Za-z.-]+)?$';

module.exports = {
    RELEASE_OWNER,
    RELEASE_REPO,
    RELEASE_REPOSITORY,
    RELEASE_TAG_PATTERN_SOURCE
};
