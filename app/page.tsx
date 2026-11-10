import { redirect } from "next/navigation";

// AIVACS: este app é um painel interno para a agência e os clientes, não um
// site público. A raiz leva direto ao painel (o proxy manda para o login
// quem não estiver autenticado).
export default function Home() {
  redirect("/dashboard");
}
