import Image from "next/image";

import React, { ReactNode } from "react";

const AuthLayout = ({ children }: { children: ReactNode }) => {
  return (
    <main className="flex min-h-screen items-center justify-center bg-cover bg-center bg-no-repeat px-4 py-10">
      <section className="min-w-full rounded-[10px] border px-4 py-10 shadow-md sm:min-w-[520px] sm:px-8">
        <div className="flex items-center justify-between gap-2">
          <div className="space-y-2.5">
            <h1 className="font-bold">Join Bookstore</h1>
            <p className="">To get your questions answered</p>
          </div>
          <Image
            src="images/books.png"
            alt="Bookstore Logo"
            width={50}
            height={50}
            className="object-contain"
          />
        </div>

        {children}

        {/* <SocialAuthForm /> */}
      </section>
    </main>
  );
};

export default AuthLayout;
