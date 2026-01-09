<?php
/**
 * MailAdmin Database Handler
 * Manages virtual domains, users, and aliases
 */

namespace MailAdmin;

class MailDB
{
    private $pdo;
    
    public function __construct(string $host, string $dbname, string $user, string $pass)
    {
        try {
            $this->pdo = new \PDO(
                "mysql:host={$host};dbname={$dbname};charset=utf8mb4",
                $user,
                $pass,
                [
                    \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
                    \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
                    \PDO::ATTR_EMULATE_PREPARES => false
                ]
            );
        } catch (\PDOException $e) {
            throw new \Exception("Database connection failed: " . $e->getMessage());
        }
    }
    
    // ========================================
    // DOMAIN MANAGEMENT
    // ========================================
    
    public function getDomains(): array
    {
        $stmt = $this->pdo->query(
            "SELECT id, name, created_at FROM virtual_domains ORDER BY name"
        );
        return $stmt->fetchAll();
    }
    
    public function addDomain(string $domain): void
    {
        if (empty($domain)) {
            throw new \Exception("Domain name cannot be empty");
        }
        
        if (!$this->isValidDomain($domain)) {
            throw new \Exception("Invalid domain name format");
        }
        
        $stmt = $this->pdo->prepare(
            "INSERT INTO virtual_domains (name) VALUES (:domain)"
        );
        
        try {
            $stmt->execute(['domain' => $domain]);
        } catch (\PDOException $e) {
            if ($e->getCode() == 23000) {
                throw new \Exception("Domain already exists");
            }
            throw new \Exception("Failed to add domain: " . $e->getMessage());
        }
    }
    
    public function removeDomain(string $domain): void
    {
        if (empty($domain)) {
            throw new \Exception("Domain name cannot be empty");
        }
        
        // Check if domain has users
        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM virtual_users u 
             JOIN virtual_domains d ON u.domain_id = d.id 
             WHERE d.name = :domain"
        );
        $stmt->execute(['domain' => $domain]);
        $userCount = $stmt->fetchColumn();
        
        if ($userCount > 0) {
            throw new \Exception("Cannot delete domain with {$userCount} users. Delete users first.");
        }
        
        $stmt = $this->pdo->prepare(
            "DELETE FROM virtual_domains WHERE name = :domain"
        );
        $stmt->execute(['domain' => $domain]);
        
        if ($stmt->rowCount() === 0) {
            throw new \Exception("Domain not found");
        }
    }
    
    // ========================================
    // USER MANAGEMENT
    // ========================================
    
    public function getUsers(string $domain = ''): array
    {
        if (empty($domain)) {
            $stmt = $this->pdo->query(
                "SELECT u.id, u.email, d.name as domain, u.quota, u.enabled, u.created_at 
                 FROM virtual_users u 
                 JOIN virtual_domains d ON u.domain_id = d.id 
                 ORDER BY u.email"
            );
            return $stmt->fetchAll();
        } else {
            $stmt = $this->pdo->prepare(
                "SELECT u.id, u.email, u.quota, u.enabled, u.created_at 
                 FROM virtual_users u 
                 JOIN virtual_domains d ON u.domain_id = d.id 
                 WHERE d.name = :domain 
                 ORDER BY u.email"
            );
            $stmt->execute(['domain' => $domain]);
            return $stmt->fetchAll();
        }
    }
    
    public function addUser(string $email, string $password): void
    {
        if (empty($email) || empty($password)) {
            throw new \Exception("Email and password are required");
        }
        
        if (!$this->isValidEmail($email)) {
            throw new \Exception("Invalid email format");
        }
        
        list($username, $domain) = explode('@', $email);
        
        // Get domain ID
        $stmt = $this->pdo->prepare(
            "SELECT id FROM virtual_domains WHERE name = :domain"
        );
        $stmt->execute(['domain' => $domain]);
        $domainId = $stmt->fetchColumn();
        
        if (!$domainId) {
            throw new \Exception("Domain {$domain} does not exist. Create it first.");
        }
        
        // Hash password using SHA512-CRYPT
        $hashedPassword = $this->hashPassword($password);
        
        // Insert user
        $stmt = $this->pdo->prepare(
            "INSERT INTO virtual_users (domain_id, email, password) 
             VALUES (:domain_id, :email, :password)"
        );
        
        try {
            $stmt->execute([
                'domain_id' => $domainId,
                'email' => $email,
                'password' => $hashedPassword
            ]);
        } catch (\PDOException $e) {
            if ($e->getCode() == 23000) {
                throw new \Exception("User already exists");
            }
            throw new \Exception("Failed to create user: " . $e->getMessage());
        }
    }
    
    public function removeUser(string $email): void
    {
        if (empty($email)) {
            throw new \Exception("Email is required");
        }
        
        $stmt = $this->pdo->prepare(
            "DELETE FROM virtual_users WHERE email = :email"
        );
        $stmt->execute(['email' => $email]);
        
        if ($stmt->rowCount() === 0) {
            throw new \Exception("User not found");
        }
    }
    
    public function setUserEnabled(string $email, bool $enabled): void
    {
        if (empty($email)) {
            throw new \Exception("Email is required");
        }
        
        $stmt = $this->pdo->prepare(
            "UPDATE virtual_users SET enabled = :enabled WHERE email = :email"
        );
        $stmt->execute([
            'enabled' => $enabled ? 1 : 0,
            'email' => $email
        ]);
        
        if ($stmt->rowCount() === 0) {
            throw new \Exception("User not found");
        }
    }
    
    public function changePassword(string $email, string $password): void
    {
        if (empty($email) || empty($password)) {
            throw new \Exception("Email and password are required");
        }
        
        $hashedPassword = $this->hashPassword($password);
        
        $stmt = $this->pdo->prepare(
            "UPDATE virtual_users SET password = :password WHERE email = :email"
        );
        $stmt->execute([
            'password' => $hashedPassword,
            'email' => $email
        ]);
        
        if ($stmt->rowCount() === 0) {
            throw new \Exception("User not found");
        }
    }
    
    // ========================================
    // ALIAS MANAGEMENT
    // ========================================
    
    public function getAliases(string $domain = ''): array
    {
        if (empty($domain)) {
            $stmt = $this->pdo->query(
                "SELECT a.id, a.source, a.destination, d.name as domain 
                 FROM virtual_aliases a 
                 JOIN virtual_domains d ON a.domain_id = d.id 
                 ORDER BY a.source"
            );
            return $stmt->fetchAll();
        } else {
            $stmt = $this->pdo->prepare(
                "SELECT a.id, a.source, a.destination 
                 FROM virtual_aliases a 
                 JOIN virtual_domains d ON a.domain_id = d.id 
                 WHERE d.name = :domain 
                 ORDER BY a.source"
            );
            $stmt->execute(['domain' => $domain]);
            return $stmt->fetchAll();
        }
    }
    
    public function addAlias(string $source, string $destination): void
    {
        if (empty($source) || empty($destination)) {
            throw new \Exception("Source and destination are required");
        }
        
        if (!$this->isValidEmail($source) || !$this->isValidEmail($destination)) {
            throw new \Exception("Invalid email format");
        }
        
        list($username, $domain) = explode('@', $source);
        
        // Get domain ID
        $stmt = $this->pdo->prepare(
            "SELECT id FROM virtual_domains WHERE name = :domain"
        );
        $stmt->execute(['domain' => $domain]);
        $domainId = $stmt->fetchColumn();
        
        if (!$domainId) {
            throw new \Exception("Domain {$domain} does not exist");
        }
        
        // Insert alias
        $stmt = $this->pdo->prepare(
            "INSERT INTO virtual_aliases (domain_id, source, destination) 
             VALUES (:domain_id, :source, :destination)"
        );
        
        try {
            $stmt->execute([
                'domain_id' => $domainId,
                'source' => $source,
                'destination' => $destination
            ]);
        } catch (\PDOException $e) {
            if ($e->getCode() == 23000) {
                throw new \Exception("Alias already exists");
            }
            throw new \Exception("Failed to create alias: " . $e->getMessage());
        }
    }
    
    public function removeAlias(string $source): void
    {
        if (empty($source)) {
            throw new \Exception("Source is required");
        }
        
        $stmt = $this->pdo->prepare(
            "DELETE FROM virtual_aliases WHERE source = :source"
        );
        $stmt->execute(['source' => $source]);
        
        if ($stmt->rowCount() === 0) {
            throw new \Exception("Alias not found");
        }
    }
    
    // ========================================
    // HELPERS
    // ========================================
    
    private function hashPassword(string $password): string
    {
        // Try doveadm first (if available)
        $doveadmPath = '/usr/bin/doveadm';
        if (file_exists($doveadmPath)) {
            $escapedPassword = escapeshellarg($password);
            $output = shell_exec("{$doveadmPath} pw -s SHA512-CRYPT -p {$escapedPassword} 2>/dev/null");
            if ($output) {
                return trim($output);
            }
        }
        
        // Fallback to PHP's crypt()
        return crypt($password, '$6$rounds=5000$' . $this->generateSalt(16) . '$');
    }
    
    private function generateSalt(int $length): string
    {
        $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./';
        $salt = '';
        for ($i = 0; $i < $length; $i++) {
            $salt .= $chars[random_int(0, strlen($chars) - 1)];
        }
        return $salt;
    }
    
    private function isValidEmail(string $email): bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }
    
    private function isValidDomain(string $domain): bool
    {
        return preg_match('/^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$/', $domain);
    }
}
