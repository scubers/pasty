extern "C" int sodium_init(void);

int main() {
    return sodium_init() < 0 ? 1 : 0;
}
