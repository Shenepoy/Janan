import java.io.FileInputStream;
import java.util.Properties;

/** Checks serialization with the same byte-oriented loader used by Gradle. */
class SigningPropertiesProbe {
    public static void main(String[] args) throws Exception {
        Properties properties = new Properties();
        try (FileInputStream input = new FileInputStream(args[0])) {
            properties.load(input);
        }
        for (String key : new String[]{"storeFile", "storePassword", "keyAlias", "keyPassword"}) {
            if (!System.getenv("TEST_" + key).equals(properties.getProperty(key))) {
                throw new AssertionError("Property round trip failed: " + key);
            }
        }
        System.out.println("Signing properties round trip passed");
    }
}
