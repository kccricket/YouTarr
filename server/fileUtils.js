const fs = require('fs').promises;
const path = require('path');

/**
 * Creates blank files if they don't exist
 * @param {string[]} filePaths - Array of file paths to check and create
 * @returns {Promise<void>}
 */
async function createBlankFilesIfNotExist(filePaths) {
  for (const filePath of filePaths) {
    try {
      // Check if file exists
      await fs.access(filePath);
      console.log(`File already exists: ${filePath}`);
    } catch (error) {
      if (error.code === 'ENOENT') {
        // Ensure directory exists
        const dirPath = path.dirname(filePath);
        try {
          await fs.mkdir(dirPath, { recursive: true });
        } catch (mkdirErr) {
          if (mkdirErr.code !== 'EEXIST') {
            console.error(`Error creating directory ${dirPath}:`, mkdirErr);
            throw mkdirErr;
          }
        }
        
        // Create blank file
        await fs.writeFile(filePath, '');
        console.log(`Created blank file: ${filePath}`);
      } else {
        console.error(`Error accessing ${filePath}:`, error);
        throw error;
      }
    }
  }
}

/**
 * Creates blank channels.list and complete.list files if they don't exist
 * @returns {Promise<void>}
 */
async function initializeConfigFiles() {
  const configDir = path.resolve(__dirname, '../config');
  const filesToCreate = [
    path.join(configDir, 'channels.list'),
    path.join(configDir, 'complete.list')
  ];
  
  await createBlankFilesIfNotExist(filesToCreate);
}

module.exports = {
  createBlankFilesIfNotExist,
  initializeConfigFiles
};
