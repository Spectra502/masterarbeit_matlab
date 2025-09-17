function x_aug = augment_translation(x, shift_amount)
    N = numel(x);
    s = max(min(round(shift_amount), N-1), -(N-1));
    x_aug = zeros(size(x));
    if s >= 0
        x_aug(1+s:N) = x(1:N-s);
    else
        k = -s;
        x_aug(1:N-k) = x(1+k:N);
    end
end