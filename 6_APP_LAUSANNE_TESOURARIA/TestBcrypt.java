import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
public class TestBcrypt {
    public static void main(String[] args) {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        String hash = encoder.encode("Pr.124578.");
        boolean matches = encoder.matches("Pr.124578.", hash);
        System.out.println("Matches: " + matches);
    }
}
