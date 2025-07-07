import bcrypt

class Hasher:
    def __init__(self, password: str):
        self.password = password

    @classmethod
    def check_password(cls, password, hashed_password) -> bool:
        return bcrypt.checkpw(password.encode(), hashed_password.encode())

    @classmethod
    def _hash(cls, password:str) -> str:
        return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
            
    def generate(self) -> list:
        return self._hash(self.password)