function x_aug = augment_masking_noise(x, mask_fraction)
    % Applies masking noise to the signal
    mask = rand(size(x)) > mask_fraction;
    x_aug = x .* mask; 
end