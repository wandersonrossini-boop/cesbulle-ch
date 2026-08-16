package com.tesourariacme.api.infrastructure;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@Service
public class LocalStorageService implements StorageService {

    private final Path rootLocation = Paths.get("uploads");

    public LocalStorageService() {
        try {
            Files.createDirectories(rootLocation);
        } catch (IOException e) {
            throw new RuntimeException("Could not initialize storage folder!", e);
        }
    }

    @Override
    public void save(String path, MultipartFile file) throws IOException {
        Path destinationFile = this.rootLocation.resolve(Paths.get(path)).normalize().toAbsolutePath();
        Files.createDirectories(destinationFile.getParent());
        Files.copy(file.getInputStream(), destinationFile, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
    }

    @Override
    public byte[] load(String path) throws IOException {
        Path file = this.rootLocation.resolve(Paths.get(path)).normalize().toAbsolutePath();
        if (Files.exists(file)) {
            return Files.readAllBytes(file);
        } else {
            throw new IOException("File not found: " + path);
        }
    }
}
