module.exports = {
  rootDir: '.', testEnvironment: 'jsdom',
  transformIgnorePatterns: ['node_modules/(?!(chai|jsoncrush|@tailuge/messaging|three))'],
  transform: {'^.+\\.(t|j)sx?$': ['@swc/jest', {jsc:{parser:{syntax:'typescript',tsx:true},target:'es2020'}}]},
  moduleNameMapper: {'^@tailuge/messaging$':'<rootDir>/web/no-network.ts', '.*/scorereporter$':'<rootDir>/web/local-scores.ts', '.*/shorten$':'<rootDir>/web/local-share.ts','.*GLTFExporter':'<rootDir>/upstream/test/mocks/gltfexporter.ts','.*GLTFLoader':'<rootDir>/upstream/test/mocks/gltfloader.ts','.*/sound':'<rootDir>/upstream/test/mocks/mocksound.ts','^three$':'<rootDir>/node_modules/three/build/three.module.js'},
};
