<?php
/**
 * MailAdmin Sieve Script Manager
 * Manages user sieve scripts for signatures and vacation messages
 */

namespace MailAdmin;

class SieveManager
{
    private $basePath;
    
    public function __construct(string $basePath)
    {
        $this->basePath = rtrim($basePath, '/');
    }
    
    // ========================================
    // SIGNATURE MANAGEMENT
    // ========================================
    
    /**
     * Get user's signature
     */
    public function getSignature(string $email): ?string
    {
        $sievePath = $this->getUserSievePath($email);
        $signatureFile = "{$sievePath}/signature.txt";
        
        if (!file_exists($signatureFile)) {
            return null;
        }
        
        return file_get_contents($signatureFile);
    }
    
    /**
     * Set user's signature
     */
    public function setSignature(string $email, string $signature): void
    {
        $sievePath = $this->getUserSievePath($email);
        $this->ensureSieveDirectory($sievePath);
        
        // Save signature text
        $signatureFile = "{$sievePath}/signature.txt";
        file_put_contents($signatureFile, $signature);
        
        // Update main sieve script
        $this->updateMainScript($email);
        
        // Compile sieve script
        $this->compileSieveScript($email);
    }
    
    // ========================================
    // VACATION MANAGEMENT
    // ========================================
    
    /**
     * Get user's vacation settings
     */
    public function getVacation(string $email): ?array
    {
        $sievePath = $this->getUserSievePath($email);
        $vacationFile = "{$sievePath}/vacation.json";
        
        if (!file_exists($vacationFile)) {
            return null;
        }
        
        $data = json_decode(file_get_contents($vacationFile), true);
        
        // Check if vacation is still active
        if (isset($data['end_date'])) {
            $endDate = strtotime($data['end_date']);
            if ($endDate < time()) {
                // Vacation expired, disable it
                $this->disableVacation($email);
                return null;
            }
        }
        
        return $data;
    }
    
    /**
     * Set vacation message
     */
    public function setVacation(
        string $email, 
        string $subject, 
        string $message, 
        string $startDate, 
        string $endDate
    ): void {
        $sievePath = $this->getUserSievePath($email);
        $this->ensureSieveDirectory($sievePath);
        
        // Validate dates
        $start = strtotime($startDate);
        $end = strtotime($endDate);
        
        if ($start === false || $end === false) {
            throw new \Exception("Invalid date format");
        }
        
        if ($end <= $start) {
            throw new \Exception("End date must be after start date");
        }
        
        // Check maximum vacation period (30 days as per dovecot config)
        $maxPeriod = 30 * 24 * 60 * 60; // 30 days in seconds
        if (($end - $start) > $maxPeriod) {
            throw new \Exception("Vacation period cannot exceed 30 days");
        }
        
        // Save vacation settings
        $vacationData = [
            'subject' => $subject,
            'message' => $message,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'enabled' => true
        ];
        
        $vacationFile = "{$sievePath}/vacation.json";
        file_put_contents($vacationFile, json_encode($vacationData, JSON_PRETTY_PRINT));
        
        // Update main sieve script
        $this->updateMainScript($email);
        
        // Compile sieve script
        $this->compileSieveScript($email);
    }
    
    /**
     * Disable vacation message
     */
    public function disableVacation(string $email): void
    {
        $sievePath = $this->getUserSievePath($email);
        $vacationFile = "{$sievePath}/vacation.json";
        
        if (file_exists($vacationFile)) {
            unlink($vacationFile);
        }
        
        // Update main sieve script
        $this->updateMainScript($email);
        
        // Compile sieve script
        $this->compileSieveScript($email);
    }
    
    // ========================================
    // MAIN SCRIPT GENERATION
    // ========================================
    
    /**
     * Generate and update the main sieve script
     */
    private function updateMainScript(string $email): void
    {
        $sievePath = $this->getUserSievePath($email);
        $mainScript = "{$sievePath}/main.sieve";
        
        // Start building the script
        $script = "require [\"fileinto\", \"envelope\", \"vacation\", \"vacation-seconds\", \"relational\", \"comparator-i;ascii-numeric\"];\n\n";
        
        // Add vacation if active
        $vacation = $this->getVacation($email);
        if ($vacation && $this->isVacationActive($vacation)) {
            $script .= $this->generateVacationRule($vacation);
        }
        
        // Add signature if exists
        $signature = $this->getSignature($email);
        if ($signature) {
            $script .= $this->generateSignatureRule($signature);
        }
        
        // Save main script
        file_put_contents($mainScript, $script);
        chmod($mainScript, 0600);
        
        // Create/update symlink to active script
        $activeScript = $this->getUserMaildirPath($email) . '/.dovecot.sieve';
        if (file_exists($activeScript) || is_link($activeScript)) {
            unlink($activeScript);
        }
        symlink($mainScript, $activeScript);
        
        // Set ownership to vmail
        $this->chownVmail($mainScript);
        $this->chownVmail($activeScript);
    }
    
    /**
     * Generate vacation rule
     */
    private function generateVacationRule(array $vacation): string
    {
        $subject = addslashes($vacation['subject']);
        $message = addslashes($vacation['message']);
        
        $script = "# Vacation message\n";
        $script .= "if true {\n";
        $script .= "  vacation\n";
        $script .= "    :days 1\n";
        $script .= "    :subject \"{$subject}\"\n";
        $script .= "    \"{$message}\";\n";
        $script .= "}\n\n";
        
        return $script;
    }
    
    /**
     * Generate signature rule (add signature to outgoing mail)
     */
    private function generateSignatureRule(string $signature): string
    {
        // Note: Adding signatures via Sieve is complex and not recommended
        // This is just a placeholder. In practice, signatures should be
        // managed by the email client or via IMAP settings
        
        // For now, we just store the signature text for the webmail to use
        // Real implementation would require more complex Sieve scripting
        // or integration with the MTA
        
        return "# Signature stored in signature.txt\n\n";
    }
    
    /**
     * Check if vacation is currently active
     */
    private function isVacationActive(array $vacation): bool
    {
        if (!isset($vacation['start_date']) || !isset($vacation['end_date'])) {
            return false;
        }
        
        $now = time();
        $start = strtotime($vacation['start_date']);
        $end = strtotime($vacation['end_date']);
        
        return ($now >= $start && $now <= $end);
    }
    
    // ========================================
    // SIEVE COMPILATION
    // ========================================
    
    /**
     * Compile sieve script using sievec
     */
    private function compileSieveScript(string $email): void
    {
        $sievePath = $this->getUserSievePath($email);
        $mainScript = "{$sievePath}/main.sieve";
        $compiledScript = "{$sievePath}/main.svbin";
        
        if (!file_exists($mainScript)) {
            return;
        }
        
        // Compile using sievec
        $sievec = '/usr/bin/sievec';
        if (file_exists($sievec)) {
            $output = [];
            $returnCode = 0;
            exec("{$sievec} {$mainScript} {$compiledScript} 2>&1", $output, $returnCode);
            
            if ($returnCode !== 0) {
                throw new \Exception("Failed to compile sieve script: " . implode("\n", $output));
            }
            
            $this->chownVmail($compiledScript);
        }
    }
    
    // ========================================
    // PATH HELPERS
    // ========================================
    
    /**
     * Get user's maildir path
     */
    private function getUserMaildirPath(string $email): string
    {
        list($username, $domain) = explode('@', $email);
        return "{$this->basePath}/{$domain}/{$username}";
    }
    
    /**
     * Get user's sieve directory path
     */
    private function getUserSievePath(string $email): string
    {
        return $this->getUserMaildirPath($email) . '/sieve';
    }
    
    /**
     * Ensure sieve directory exists
     */
    private function ensureSieveDirectory(string $path): void
    {
        if (!is_dir($path)) {
            mkdir($path, 0700, true);
            $this->chownVmail($path);
        }
    }
    
    /**
     * Change ownership to vmail user
     */
    private function chownVmail(string $path): void
    {
        // Get vmail uid/gid
        $vmail = posix_getpwnam('vmail');
        if ($vmail) {
            chown($path, $vmail['uid']);
            chgrp($path, $vmail['gid']);
        }
    }
    
    // ========================================
    // VALIDATION
    // ========================================
    
    /**
     * Validate email format
     */
    private function isValidEmail(string $email): bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false 
            && strpos($email, '@') !== false;
    }
}
