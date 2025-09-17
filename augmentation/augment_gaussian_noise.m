function x_aug = augment_gaussian_noise(x, noise_level)
    % Adds Gaussian noise to the signal
    noise = noise_level * randn(size(x)); 
    x_aug = x + noise; 
end