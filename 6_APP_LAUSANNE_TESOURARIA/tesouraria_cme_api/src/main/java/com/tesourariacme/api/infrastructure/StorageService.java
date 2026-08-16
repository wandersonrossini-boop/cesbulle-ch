package com.tesourariacme.api.infrastructure;

import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;

public interface StorageService {
    void save(String path, MultipartFile file) throws IOException;
    byte[] load(String path) throws IOException;
}
